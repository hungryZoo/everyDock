import ApplicationServices
import AppKit
import DockCore

enum WindowActionResult: Sendable { case minimized, restored, activate, failed(WindowFailure) }

/// Immutable remote AX identity. Messaging is performed only by detached WindowActions tasks.
/// CFEqual compares remote objects, so two equal titles never become the same window.
struct WindowReference: @unchecked Sendable, Hashable {
    let pid: pid_t
    let element: AXUIElement
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(pid); hasher.combine(CFHash(element)) }
}
struct WindowDescription: Sendable {
    let reference: WindowReference
    let title: String
    let frame: CGRect
    let minimized: Bool
    let canClose: Bool
}
struct WindowListResult: Sendable {
    let windows: [WindowDescription]
    let failure: WindowFailure?
}
enum WindowCloseResult: Sendable {
    case closed, awaitingApplication, failed(WindowFailure)
    var message: String? {
        switch self {
        case .closed: nil
        case .awaitingApplication: "앱에서 저장 확인이나 창 닫기를 완료해 주세요. 나머지 창은 닫지 않았습니다."
        case .failed(.permissionDenied): "macOS가 창 제어를 거부했습니다. 손쉬운 사용 권한을 확인해 주세요."
        case .failed(.noWindow): "이 창은 이미 닫혔습니다."
        case .failed(.unsupported): "이 창은 닫기 기능을 제공하지 않습니다."
        case .failed(.timedOut): "앱이 응답하지 않습니다. 잠시 후 다시 시도해 주세요."
        case .failed(.apiError(let code)): "창을 닫지 못했습니다. macOS 오류: \(code)"
        }
    }
}

enum WindowCloseSequence {
    static func perform<T: Sendable>(snapshot: [T], close: @Sendable (T) async -> WindowCloseResult) async -> WindowCloseResult {
        for window in snapshot {
            if Task.isCancelled { return .awaitingApplication }
            switch await close(window) {
            case .closed, .failed(.noWindow): continue
            case let result: return result
            }
        }
        return .closed
    }
}

/// All cross-process AX messaging stays off the rendering thread.
enum WindowActions {
    static func fitZoomedWindow(_ reference: WindowReference, areas: [WindowWorkArea], state: WindowZoomState) async -> (WindowZoomState, WindowFailure?) {
        let request = Task.detached(priority: .userInitiated) { () -> (WindowZoomState, WindowFailure?) in
            guard !Task.isCancelled else { return (state, nil) }
            var next = state
            let window = reference.element
            // Resize notifications can refer to a helper, dialog, minimized or full-screen window.
            guard string(window, kAXRoleAttribute) == kAXWindowRole,
                  string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
                  !bool(window, kAXMinimizedAttribute) else { return (state, nil) }
            var fullScreen: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreen) == .success,
                  fullScreen as? Bool == false else { return (state, nil) }
            let old = frame(window)
            guard let adjusted = next.destination(for: old, in: areas) else { return (next, nil) }
            WindowTrace.write("fit \(old) -> \(adjusted)")
            var settable: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable) == .success, settable.boolValue else { return (state, .unsupported) }
            if adjusted.origin != old.origin {
                guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable) == .success, settable.boolValue else { return (state, .unsupported) }
            }
            let restoring = state.fitted != nil && adjusted == state.normal
            let ticks: AsyncStream<Double>
            if restoring { ticks = await WindowRestoreClock.frames(for: old) }
            else { ticks = AsyncStream { $0.yield(1); $0.finish() } }
            var last = old
            for await progress in ticks {
                guard !Task.isCancelled else { return (state, nil) }
                let current = frame(window)
                // Stop if the user or application moves/resizes the window during the transition.
                if abs(current.minX - last.minX) > 3 || abs(current.minY - last.minY) > 3 ||
                    abs(current.width - last.width) > 3 || abs(current.height - last.height) > 3 || bool(window, kAXMinimizedAttribute) {
                    next.reset(); next.observe(current, in: areas)
                    return (next, nil)
                }
                let step = WindowFrameAnimation.frame(from: old, to: adjusted, progress: progress)
                if let failure = setFrame(window, from: last, to: step) { return (state, failure) }
                last = step
            }
            let actual = frame(window)
            // Apps can enforce a minimum size. Do not keep reapplying a rejected correction.
            if abs(actual.width - adjusted.width) > 2 || abs(actual.height - adjusted.height) > 2 {
                next.reset()
            }
            return (next, nil)
        }
        return await withTaskCancellationHandler { await request.value } onCancel: { request.cancel() }
    }

    private static func setFrame(_ window: AXUIElement, from old: CGRect, to target: CGRect) -> WindowFailure? {
        var size = target.size
        guard let value = AXValueCreate(.cgSize, &size) else { return .unsupported }
        let resized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        guard resized == .success else { return .classify(resized) }
        if target.origin != old.origin {
            var point = target.origin
            guard let value = AXValueCreate(.cgPoint, &point) else { return .unsupported }
            let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
            if moved != .success { return .classify(moved) }
        }
        return nil
    }

    static func toggle(pid: pid_t, active: Bool, minimize: Bool) async -> WindowActionResult {
        await Task.detached(priority: .userInitiated) {
            let application = client(pid)
            switch windows(application) {
            case .failure(let failure): return .failed(failure)
            case .success(let windows):
                if active && minimize {
                    let preferred = [element(application, kAXFocusedWindowAttribute), element(application, kAXMainWindowAttribute)]
                        .compactMap { $0 }.first { candidate in windows.contains { CFEqual($0, candidate) } }
                    let target = preferred ?? windows.first { !bool($0, kAXMinimizedAttribute) }
                    if let target, !bool(target, kAXMinimizedAttribute) {
                        if let button = element(target, kAXMinimizeButtonAttribute) {
                            let pressed = AXUIElementPerformAction(button, kAXPressAction as CFString)
                            if pressed == .success { return .minimized }
                            if pressed == .apiDisabled { return .failed(.permissionDenied) }
                        }
                        let error = AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                        return error == .success ? .minimized : .failed(.classify(error))
                    }
                }
                let minimized = windows.filter { bool($0, kAXMinimizedAttribute) }
                if !minimized.isEmpty {
                    var restored = false
                    var failure: WindowFailure = .unsupported
                    for window in minimized {
                        let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                        if error == .success { _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString); restored = true }
                        else { failure = .classify(error) }
                    }
                    return restored ? .restored : .failed(failure)
                }
                // Reopen applications with no document windows, including Finder's desktop-only state.
                return .activate
            }
        }.value
    }

    static func list(pid: pid_t) async -> WindowListResult {
        await Task.detached(priority: .userInitiated) {
            switch windows(client(pid)) {
            case .success(let windows):
                return WindowListResult(windows: windows.map {
                    WindowDescription(reference: WindowReference(pid: pid, element: $0), title: string($0, kAXTitleAttribute),
                                      frame: frame($0), minimized: bool($0, kAXMinimizedAttribute), canClose: closeButton($0) != nil)
                }, failure: nil)
            case .failure(let failure): return WindowListResult(windows: [], failure: failure)
            }
        }.value
    }

    static func focus(_ reference: WindowReference) async -> WindowFailure? {
        await Task.detached(priority: .userInitiated) {
            if let failure = validate(reference) { return failure }
            let window = reference.element
            if bool(window, kAXMinimizedAttribute) {
                let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                if error != .success { return .classify(error) }
            }
            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            let error = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return error == .success ? nil : .classify(error)
        }.value
    }

    static func close(_ reference: WindowReference) async -> WindowCloseResult {
        await Task.detached(priority: .userInitiated) { await closeAndWait(reference) }.value
    }

    static func closeAll(pid: pid_t) async -> WindowCloseResult {
        await Task.detached(priority: .userInitiated) {
            switch windows(client(pid)) {
            case .failure(let failure): return .failed(failure)
            case .success(let snapshot):
                // Snapshot identities: never close a new window created while the operation is running.
                let references = snapshot.map { WindowReference(pid: pid, element: $0) }
                return await WindowCloseSequence.perform(snapshot: references, close: closeAndWait)
            }
        }.value
    }

    private static func closeAndWait(_ reference: WindowReference) async -> WindowCloseResult {
        if let failure = validate(reference) { return .failed(failure) }
        let application = client(reference.pid)
        if hasDialog(application) { return .awaitingApplication }
        guard let button = closeButton(reference.element) else { return .failed(.unsupported) }
        let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
        guard error == .success else { return .failed(.classify(error)) }
        // A successful Press can open a save sheet. Wait for disappearance before continuing.
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { return .awaitingApplication }
            if let failure = validate(reference) {
                return failure == .noWindow ? .closed : .failed(failure)
            }
            if hasDialog(application) { return .awaitingApplication }
        }
        return .awaitingApplication
    }
    private static func hasDialog(_ application: AXUIElement) -> Bool {
        guard case .success(let list) = windows(application) else { return true }
        return list.contains {
            bool($0, kAXModalAttribute) || elements($0, kAXChildrenAttribute).contains { string($0, kAXRoleAttribute) == kAXSheetRole }
                || [kAXDialogSubrole, kAXSystemDialogSubrole].contains(string($0, kAXSubroleAttribute))
        }
    }
    private static func validate(_ reference: WindowReference) -> WindowFailure? {
        switch windows(client(reference.pid)) {
        case .failure(let failure): return failure
        case .success(let list): return list.contains { CFEqual($0, reference.element) } ? nil : .noWindow
        }
    }
    private static func client(_ pid: pid_t) -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        return application
    }
    private static func windows(_ application: AXUIElement) -> Result<[AXUIElement], WindowFailure> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
        if error == .noValue { return .success([]) }
        guard error == .success else { return .failure(.classify(error)) }
        var result: [AXUIElement] = []
        for window in value as? [AXUIElement] ?? [] {
            let role = string(window, kAXRoleAttribute), subrole = string(window, kAXSubroleAttribute)
            let supported = [kAXStandardWindowSubrole, kAXDialogSubrole, kAXSystemDialogSubrole].contains(subrole)
                || (subrole.isEmpty && (element(window, kAXCloseButtonAttribute) != nil || element(window, kAXMinimizeButtonAttribute) != nil))
            guard role == kAXWindowRole, supported, !result.contains(where: { CFEqual($0, window) }) else { continue }
            result.append(window)
        }
        return .success(result)
    }
    private static func closeButton(_ window: AXUIElement) -> AXUIElement? {
        guard let button = element(window, kAXCloseButtonAttribute), bool(button, kAXEnabledAttribute) else { return nil }
        return button
    }
    private static func elements(_ owner: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(owner, attribute as CFString, &value)
        return value as? [AXUIElement] ?? []
    }
    private static func element(_ owner: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(owner, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
    private static func string(_ owner: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(owner, attribute as CFString, &value)
        return value as? String ?? ""
    }
    private static func frame(_ window: AXUIElement) -> CGRect {
        var position: CFTypeRef?, size: CFTypeRef?
        var point = CGPoint.zero, extent = CGSize.zero
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
           let position, CFGetTypeID(position) == AXValueGetTypeID() {
            AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point)
        }
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
           let size, CFGetTypeID(size) == AXValueGetTypeID() {
            AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent)
        }
        return CGRect(origin: point, size: extent)
    }
    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success && (value as? Bool == true)
    }
}
