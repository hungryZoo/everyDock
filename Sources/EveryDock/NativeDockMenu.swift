import AppKit
import ApplicationServices

/// Asks the real Dock to show its menu; application-owned selectors stay in their owner process.
@MainActor enum NativeDockMenu {
    private static var opening = false
    static func show(for url: URL) async -> String? {
        guard !opening else { return nil }
        opening = true
        defer { opening = false }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            return "macOS Dock을 찾지 못했습니다."
        }
        return await Task.detached(priority: .userInitiated) {
            let root = AXUIElementCreateApplication(dock)
            AXUIElementSetMessagingTimeout(root, 0.4)
            var queue: [(AXUIElement, Int)] = [(root, 0)]
            var visited = 0
            let deadline = ProcessInfo.processInfo.systemUptime + 2
            while !queue.isEmpty && visited < 250 && ProcessInfo.processInfo.systemUptime < deadline {
                let (element, depth) = queue.removeFirst(); visited += 1
                var value: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value)
                if result == .apiDisabled { return "macOS가 Dock 메뉴 접근을 거부했습니다. 손쉬운 사용 권한을 확인해 주세요." }
                if result == .cannotComplete { return "macOS Dock이 응답하지 않습니다. 잠시 후 다시 시도해 주세요." }
                let candidate = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
                if candidate?.standardizedFileURL == url.standardizedFileURL {
                    let action = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
                    if action == .success { return nil }
                    // AXShowMenu can block until tracking ends. A timeout may mean it is already open.
                    if action == .cannotComplete { return nil }
                    return "macOS Dock 메뉴를 열지 못했습니다. 오류: \(action.rawValue)"
                }
                if depth < 2 {
                    value = nil
                    let children = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
                    if children == .apiDisabled { return "macOS가 Dock 메뉴 접근을 거부했습니다. 손쉬운 사용 권한을 확인해 주세요." }
                    if children == .cannotComplete { return "macOS Dock이 응답하지 않습니다. 잠시 후 다시 시도해 주세요." }
                    for child in value as? [AXUIElement] ?? [] { queue.append((child, depth + 1)) }
                }
            }
            if ProcessInfo.processInfo.systemUptime >= deadline { return "macOS Dock 메뉴 조회 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요." }
            return "기본 Dock에서 이 앱의 항목을 찾지 못했습니다. 앱 실행 후 다시 시도하거나 everyDock 메뉴를 사용해 주세요."
        }.value
    }
}
