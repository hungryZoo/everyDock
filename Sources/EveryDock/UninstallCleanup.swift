import AppKit
import DockCore
import ServiceManagement

/// Called by Homebrew only on explicit removal, never during an upgrade.
@MainActor enum UninstallCleanup {
    static func run() throws {
        let domain = "app.everydock.mac"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: domain)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        others.forEach { _ = $0.terminate() }
        let deadline = Date().addingTimeInterval(10)
        while others.contains(where: { !$0.isTerminated }), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        guard others.allSatisfy(\.isTerminated) else {
            throw NSError(domain: domain, code: 1, userInfo: [NSLocalizedDescriptionKey: "실행 중인 everyDock을 종료한 뒤 다시 제거해 주세요."])
        }
        try NativeDockManager.recoverForUninstall()
        if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
        PreferenceReset.clear(domain: domain, defaults: .standard)
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        for relative in ["Caches/\(domain)", "Saved Application State/\(domain).savedState"] {
            let url = library.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        }
    }
}
