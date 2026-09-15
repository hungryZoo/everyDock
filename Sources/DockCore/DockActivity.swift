import Foundation

public enum DockActivity {
    public static func automaticallyPaused(enabled: Bool, onlineDisplayBuiltIns: [Bool]) -> Bool {
        enabled && !onlineDisplayBuiltIns.contains(false)
    }
}

/// A short click remains a click; movement before the hold threshold cancels arming.
public struct DockHold: Sendable {
    public static let delay = 0.30
    public private(set) var armed = false
    private var started: Double?
    public init() {}
    public mutating func begin(at time: Double) { started = time; armed = false }
    public mutating func move(distance: Double) {
        if !armed && distance > 6 { started = nil }
    }
    public mutating func arm(at time: Double) -> Bool {
        guard let started, time - started >= Self.delay else { return false }
        armed = true
        return true
    }
    public mutating func end() -> Bool {
        let consumed = armed
        started = nil; armed = false
        return consumed
    }
}
