import ApplicationServices
import AppKit

enum WindowActionResult: Sendable { case minimized, restored, activate, unavailable }

struct WindowDescription: Sendable {
    let title: String
    let frame: CGRect
    let minimized: Bool
}

/// AX messages run off the UI thread. A stalled target app must not freeze Dock animation.
enum WindowActions {
    static func toggle(pid: pid_t, active: Bool, minimize: Bool) async -> WindowActionResult {
        await Task.detached(priority: .userInitiated) {
            guard AXIsProcessTrusted() else { return .unavailable }
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.2)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { return .unavailable }
            if active && minimize {
                var focused: CFTypeRef?
                if AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &focused) == .success,
                   let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
                    let window = unsafeDowncast(focused, to: AXUIElement.self)
                    if !bool(window, kAXMinimizedAttribute) {
                        // Press the actual yellow window button so the app runs its native animation path.
                        var control: CFTypeRef?
                        if AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &control) == .success,
                           let control, CFGetTypeID(control) == AXUIElementGetTypeID(),
                           AXUIElementPerformAction(unsafeDowncast(control, to: AXUIElement.self), kAXPressAction as CFString) == .success {
                            return .minimized
                        }
                        if AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success { return .minimized }
                    }
                }
            }
            let minimized = windows.filter { bool($0, kAXMinimizedAttribute) }
            if !minimized.isEmpty {
                var restored = false
                for window in minimized {
                    if AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success {
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                        restored = true
                    }
                }
                return restored ? .restored : .unavailable
            }
            if active && minimize { return .unavailable }
            return .activate
        }.value
    }

    static func list(pid: pid_t) async -> [WindowDescription] {
        await Task.detached(priority: .userInitiated) {
            guard AXIsProcessTrusted() else { return [] }
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.2)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { return [] }
            return windows.map { WindowDescription(title: title($0), frame: frame($0), minimized: bool($0, kAXMinimizedAttribute)) }
        }.value
    }

    static func focus(pid: pid_t, title expected: String, bounds: CGRect) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard AXIsProcessTrusted() else { return false }
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.2)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { return false }
            let matching = windows.filter { title($0) == expected }
            guard let window = matching.min(by: { distance(frame($0), bounds) < distance(frame($1), bounds) }) else { return false }
            _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            return AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
        }.value
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
