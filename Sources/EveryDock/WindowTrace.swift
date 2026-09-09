import Foundation

/// Opt-in diagnostics contain geometry/status only, never window titles or images.
enum WindowTrace {
    private static let enabled = ProcessInfo.processInfo.environment["EVERYDOCK_TRACE_WINDOWS"] == "1"
    static func write(_ value: String) {
        if enabled { FileHandle.standardError.write(Data("work-area: \(value)\n".utf8)) }
    }
}
