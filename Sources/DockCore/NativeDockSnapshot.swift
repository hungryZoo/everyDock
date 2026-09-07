import Foundation

public enum DockPreferenceValue: Codable, Equatable, Sendable {
    case boolean(Bool), number(Double), string(String), absent
}

public struct NativeDockSnapshot: Codable, Sendable {
    public let original: [String: DockPreferenceValue]
    public let applied: [String: DockPreferenceValue]

    public init(original: [String: DockPreferenceValue], applied: [String: DockPreferenceValue]) {
        self.original = original
        self.applied = applied
    }

    /// Restore only our values; do not clobber preferences subsequently changed by the user.
    public func restoration(current: [String: DockPreferenceValue]) -> [String: DockPreferenceValue] {
        original.filter { current[$0.key] == applied[$0.key] }
    }
}
