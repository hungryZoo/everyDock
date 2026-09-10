import AppKit
import ApplicationServices

struct NativeMenuStep: Sendable, Equatable {
    let index: Int
    let title: String
    let identifier: String
    let submenu: Bool
    func matches(_ actual: NativeMenuStep) -> Bool { self == actual }
}
struct NativeMenuEntry: Sendable {
    let path: [NativeMenuStep]
    let title: String
    let enabled: Bool
    let marked: Bool
    let submenu: Bool
}
enum NativeMenuFailure: Error, Sendable {
    case denied, timedOut, unavailable, changed, api(Int32)
    var message: String {
        switch self {
        case .denied: "앱 메뉴 접근이 거부되었습니다. 손쉬운 사용 권한을 확인해 주세요."
        case .timedOut: "앱 메뉴가 응답하지 않습니다. 다시 시도해 주세요."
        case .unavailable: "이 앱의 Dock 메뉴를 읽을 수 없습니다. 아래의 everyDock 메뉴를 사용할 수 있습니다."
        case .changed: "앱 메뉴가 변경되었습니다. 다시 열어 선택해 주세요."
        case .api(let code): "앱 메뉴 오류: \(code). 아래의 everyDock 메뉴를 사용할 수 있습니다."
        }
    }
}

/// Render locally, but reopen and validate the real menu before forwarding a selection.
/// Remote AX objects are never kept after a menu is dismissed.
@MainActor enum NativeDockMenu {
    private static var busy = false
    static func read(for url: URL, path: [NativeMenuStep] = []) async -> Result<[NativeMenuEntry], NativeMenuFailure> {
        guard !busy else { return .failure(.timedOut) }
        busy = true; defer { busy = false }
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else { return .failure(.unavailable) }
        return await Task.detached(priority: .userInitiated) {
            do {
                let session = try NativeMenuSession(pid: pid, url: url)
                defer { session.close() }
                let menu = try session.menu(at: path)
                let entries = try session.entries(menu: menu, prefix: path)
                WindowTrace.write("menu read depth=\(path.count) entries=\(entries.count)")
                return .success(entries)
            } catch let failure as NativeMenuFailure {
                WindowTrace.write("menu read failure=\(failure)")
                return .failure(failure)
            }
            catch { return .failure(.unavailable) }
        }.value
    }
    static func select(for url: URL, path: [NativeMenuStep]) async -> NativeMenuFailure? {
        guard !busy else { return .timedOut }
        busy = true; defer { busy = false }
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else { return .unavailable }
        return await Task.detached(priority: .userInitiated) {
            do {
                let session = try NativeMenuSession(pid: pid, url: url)
                defer { session.close() }
                try session.select(path)
                return Optional<NativeMenuFailure>.none
            } catch let failure as NativeMenuFailure { return failure }
            catch { return .unavailable }
        }.value
    }
}

private final class NativeMenuSession {
    private let rootMenu: AXUIElement
    private let deadline = ProcessInfo.processInfo.systemUptime + 3
    init(pid: pid_t, url: URL) throws {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.2)
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var found: AXUIElement?
        var visited = 0
        let until = ProcessInfo.processInfo.systemUptime + 2
        while !queue.isEmpty && visited < 250 && ProcessInfo.processInfo.systemUptime < until {
            let (element, depth) = queue.removeFirst(); visited += 1
            let value = try Self.value(element, kAXURLAttribute)
            let candidate = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
            if candidate?.standardizedFileURL == url.standardizedFileURL { found = element; break }
            if depth < 2 { for child in try Self.children(element) { queue.append((child, depth + 1)) } }
        }
        guard let found else {
            WindowTrace.write("menu item missing visited=\(visited)")
            throw NativeMenuFailure.unavailable
        }
        // ShowMenu can stay in menu tracking until cancelled. Bound it, then read the live menu.
        AXUIElementSetMessagingTimeout(found, 0.05)
        let result = AXUIElementPerformAction(found, kAXShowMenuAction as CFString)
        WindowTrace.write("menu show result=\(result.rawValue)")
        guard result == .success || result == .cannotComplete else { throw Self.failure(result) }
        do {
            var pendingMenu: AXUIElement?
            for _ in 0..<20 {
                if let menu = try Self.children(found).first(where: { try Self.string($0, kAXRoleAttribute) == kAXMenuRole }) { pendingMenu = menu; break }
                Thread.sleep(forTimeInterval: 0.02)
            }
            guard let menu = pendingMenu else {
                WindowTrace.write("menu child missing")
                throw NativeMenuFailure.unavailable
            }
            rootMenu = menu
        } catch {
            _ = AXUIElementPerformAction(found, kAXCancelAction as CFString)
            throw error
        }
    }
    func close() {
        let result = AXUIElementPerformAction(rootMenu, kAXCancelAction as CFString)
        WindowTrace.write("menu cancel result=\(result.rawValue)")
    }
    func entries(menu: AXUIElement, prefix: [NativeMenuStep]) throws -> [NativeMenuEntry] {
        try checkDeadline()
        return try Self.children(menu).prefix(200).enumerated().map { index, element in
            try checkDeadline()
            let step = try identity(element, index: index)
            return NativeMenuEntry(path: prefix + [step], title: step.title,
                                   enabled: try Self.value(element, kAXEnabledAttribute) as? Bool == true,
                                   marked: !(try Self.string(element, kAXMenuItemMarkCharAttribute)).isEmpty,
                                   submenu: step.submenu)
        }
    }
    func menu(at path: [NativeMenuStep]) throws -> AXUIElement {
        guard path.count <= 5 else { throw NativeMenuFailure.unavailable }
        var menu = rootMenu
        for step in path {
            let element = try resolve(step, in: menu)
            guard step.submenu, try Self.value(element, kAXEnabledAttribute) as? Bool == true else { throw NativeMenuFailure.changed }
            let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
            guard result == .success || result == .cannotComplete else { throw Self.failure(result) }
            guard let child = try Self.children(element).first(where: { try Self.string($0, kAXRoleAttribute) == kAXMenuRole }) else { throw NativeMenuFailure.changed }
            menu = child
        }
        return menu
    }
    func select(_ path: [NativeMenuStep]) throws {
        guard let last = path.last, !last.submenu, !last.title.isEmpty else { throw NativeMenuFailure.changed }
        let menu = try menu(at: Array(path.dropLast()))
        let element = try resolve(last, in: menu)
        guard try Self.value(element, kAXEnabledAttribute) as? Bool == true else { throw NativeMenuFailure.changed }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success else { throw Self.failure(result) }
    }
    private func resolve(_ expected: NativeMenuStep, in menu: AXUIElement) throws -> AXUIElement {
        try checkDeadline()
        let children = try Self.children(menu)
        guard children.indices.contains(expected.index), expected.matches(try identity(children[expected.index], index: expected.index)) else { throw NativeMenuFailure.changed }
        return children[expected.index]
    }
    private func identity(_ element: AXUIElement, index: Int) throws -> NativeMenuStep {
        let submenu = try Self.children(element).contains { try Self.string($0, kAXRoleAttribute) == kAXMenuRole }
        return NativeMenuStep(index: index, title: try Self.string(element, kAXTitleAttribute), identifier: try Self.string(element, kAXIdentifierAttribute), submenu: submenu)
    }
    private func checkDeadline() throws { if ProcessInfo.processInfo.systemUptime > deadline { throw NativeMenuFailure.timedOut } }
    private static func children(_ element: AXUIElement) throws -> [AXUIElement] { try value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    private static func string(_ element: AXUIElement, _ key: String) throws -> String { try value(element, key) as? String ?? "" }
    private static func value(_ element: AXUIElement, _ key: String) throws -> CFTypeRef? {
        var result: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, key as CFString, &result)
        if error == .success { return result }
        if error == .attributeUnsupported || error == .noValue { return nil }
        throw failure(error)
    }
    private static func failure(_ error: AXError) -> NativeMenuFailure {
        if error == .apiDisabled { return .denied }
        if error == .cannotComplete { return .timedOut }
        return .api(error.rawValue)
    }
}
