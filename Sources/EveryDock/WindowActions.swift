import ApplicationServices
import AppKit
import DockCore

enum WindowActionResult: Sendable { case minimized, restored, activate, failed(WindowFailure) }
struct WindowDescription: Sendable {
    let title: String
    let frame: CGRect
    let minimized: Bool
}
struct WindowListResult: Sendable {
    let windows: [WindowDescription]
    let failure: WindowFailure?
}

/// All cross-process AX messaging stays off the rendering thread.
enum WindowActions {
    static func toggle(pid: pid_t, active: Bool, minimize: Bool) async -> WindowActionResult {
        await Task.detached(priority: .userInitiated) {
            let application = client(pid)
            let result = windows(application)
            guard case .success(let windows) = result else {
                if case .failure(let error) = result { return .failed(error) }
                return .failed(.noWindow)
            }
            if active && minimize {
                // Some apps expose only AXMainWindow, not AXFocusedWindow.
                let target = element(application, kAXFocusedWindowAttribute)
                    ?? element(application, kAXMainWindowAttribute)
                    ?? windows.first { !bool($0, kAXMinimizedAttribute) }
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
            return active && minimize ? .failed(.noWindow) : .activate
        }.value
    }

    static func list(pid: pid_t) async -> WindowListResult {
        await Task.detached(priority: .userInitiated) {
            switch windows(client(pid)) {
            case .success(let windows):
                return WindowListResult(windows: windows.map { WindowDescription(title: title($0), frame: frame($0), minimized: bool($0, kAXMinimizedAttribute)) }, failure: nil)
            case .failure(let failure): return WindowListResult(windows: [], failure: failure)
            }
        }.value
    }

    static func focus(pid: pid_t, title expected: String, bounds: CGRect) async -> WindowFailure? {
        await Task.detached(priority: .userInitiated) {
            switch windows(client(pid)) {
            case .failure(let failure): return failure
            case .success(let windows):
                let matching = windows.filter { title($0) == expected }
                guard let window = matching.min(by: { distance(frame($0), bounds) < distance(frame($1), bounds) }) else { return .noWindow }
                if bool(window, kAXMinimizedAttribute) {
                    let result = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    if result != .success { return .classify(result) }
                }
                _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                let result = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return result == .success ? nil : .classify(result)
            }
        }.value
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
        return .success(value as? [AXUIElement] ?? [])
    }
    private static func element(_ owner: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(owner, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
    private static func title(_ window: AXUIElement) -> String {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
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
    private static func distance(_ a: CGRect, _ b: CGRect) -> Double { abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) }
    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success && (value as? Bool == true)
    }
}
