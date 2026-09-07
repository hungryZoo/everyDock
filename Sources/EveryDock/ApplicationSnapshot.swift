import AppKit

struct ApplicationSnapshot: Sendable {
    let process: NSRunningApplication
    let pid: pid_t
    let url: URL?
    let bundleIdentifier: String?
    let name: String?
    let regular: Bool
    let active: Bool
    let hidden: Bool
    let finished: Bool

    static func collect() async -> [Self] {
        await Task.detached(priority: .utility) {
            NSWorkspace.shared.runningApplications.map { process in
                Self(process: process, pid: process.processIdentifier, url: process.bundleURL,
                     bundleIdentifier: process.bundleIdentifier, name: process.localizedName,
                     regular: process.activationPolicy == .regular, active: process.isActive,
                     hidden: process.isHidden, finished: process.isFinishedLaunching)
            }
        }.value
    }
}
