import AppKit
import DockCore
import SwiftUI

struct UpdateInfo {
    let currentVersion: SemanticVersion
    let newVersion: SemanticVersion
    let releaseNotes: String
    let releaseURL: URL
    let installMethod: InstallMethod
}

/// Daily GitHub release check and the update window. Launch never waits for the network.
/// Checks run on launch and wake only; there is no recurring timer.
@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var isChecking = false
    /// False while another first-run window (setup guide) should keep the user's attention.
    var canPresent: () -> Bool = { true }

    private let model: AppModel
    private let checker = UpdateChecker()
    private let store = UpdateCacheStore.defaultFileURL().map(UpdateCacheStore.init)
    private var window: NSWindow?
    /// Once per process: Later means the next launch, such as after a restart.
    private var hasPresentedThisRun = false
    private var wakeObservation: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        wakeObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        if let wakeObservation { NSWorkspace.shared.notificationCenter.removeObserver(wakeObservation) }
        wakeObservation = nil
    }

    var currentVersion: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }

    /// Launch and wake: show a cached update, then check in the background if a day has passed.
    func refresh() {
        presentPendingUpdateIfNeeded()
        startBackgroundCheckIfNeeded()
    }

    private func startBackgroundCheckIfNeeded() {
        guard model.preferences.checkForUpdates, let store, let currentVersion, !isChecking else { return }
        var cache = store.load()
        let now = Date().timeIntervalSince1970
        guard UpdatePolicy.shouldCheck(now: now, checkedAt: cache.checkedAt) else { return }
        // Record the attempt first so offline launches do not retry until the next day.
        cache.checkedAt = now
        try? store.save(cache)
        isChecking = true
        Task { @MainActor in
            if let release = await checker.fetchLatest(userAgent: "everyDock/\(currentVersion)") {
                var latest = store.load()
                latest.record(release)
                try? store.save(latest)
            }
            isChecking = false
            presentPendingUpdateIfNeeded()
        }
    }

    func presentPendingUpdateIfNeeded() {
        guard !hasPresentedThisRun, window == nil, model.preferences.checkForUpdates, canPresent(),
              let store, let currentVersion else { return }
        let cache = store.load()
        guard let newVersion = UpdatePolicy.pendingUpdate(current: currentVersion, cache: cache,
                                                          skippedVersion: model.preferences.skippedUpdateVersion) else { return }
        hasPresentedThisRun = true
        showWindow(UpdateInfo(currentVersion: currentVersion, newVersion: newVersion,
                              releaseNotes: cache.releaseNotes ?? "",
                              releaseURL: cache.releaseURL.flatMap(URL.init(string:)) ?? UpdateChecker.releasesURL,
                              installMethod: installMethod))
    }

    /// Check for Updates…: ignores the daily interval and any skipped version.
    func checkNow() {
        guard !isChecking else { return }
        guard let currentVersion else {
            showMessage(L10n.text("Cannot Check for Updates"), L10n.text("Could not read the current version from the app bundle."))
            return
        }
        isChecking = true
        Task { @MainActor in
            let release = await checker.fetchLatest(userAgent: "everyDock/\(currentVersion)")
            isChecking = false
            guard let release else {
                showMessage(L10n.text("Could Not Get Update Information"), L10n.text("Check your network connection and try again."))
                return
            }
            if let store {
                var cache = store.load()
                cache.checkedAt = Date().timeIntervalSince1970
                cache.record(release)
                try? store.save(cache)
            }
            guard release.version > currentVersion else {
                showMessage(L10n.text("everyDock Is Up to Date"), L10n.text("everyDock \(currentVersion) is the latest version."))
                return
            }
            hasPresentedThisRun = true
            showWindow(UpdateInfo(currentVersion: currentVersion, newVersion: release.version, releaseNotes: release.notes,
                                  releaseURL: release.url, installMethod: installMethod))
        }
    }

    private var installMethod: InstallMethod {
        InstallMethod.classify(appPath: Bundle.main.bundleURL.standardizedFileURL.path,
                               homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
                               fileExists: { FileManager.default.fileExists(atPath: $0) })
    }

    // MARK: - Window

    private func showWindow(_ info: UpdateInfo) {
        window?.close()
        let view = UpdateView(info: info,
                              onSkip: { [weak self] in self?.skip(info) },
                              onLater: { [weak self] in self?.closeWindow() },
                              onInstall: { [weak self] in self?.install(info) })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = L10n.text("everyDock Update")
        window.styleMask = [.titled, .closable]
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        self.window = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.window === window { self?.window = nil } }
        }
        // An accessory app opens behind other apps unless it activates first.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func closeWindow() {
        let window = self.window
        self.window = nil
        window?.close()
    }

    private func skip(_ info: UpdateInfo) {
        model.preferences.skippedUpdateVersion = info.newVersion.description
        closeWindow()
    }

    private func install(_ info: UpdateInfo) {
        switch info.installMethod {
        case .homebrew(let brewPath): runHomebrewUpdate(brewPath: brewPath)
        case .manual:
            NSWorkspace.shared.open(info.releaseURL)
            closeWindow()
        }
    }

    /// brew replaces the running bundle, so the script waits for this process. The normal quit
    /// below finishes pin synchronization and restores the macOS Dock before that happens.
    private func runHomebrewUpdate(brewPath: String) {
        let script = UpdateScript.homebrew(brewPath: brewPath, appPath: Bundle.main.bundleURL.standardizedFileURL.path,
                                           waitForPID: ProcessInfo.processInfo.processIdentifier)
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("everyDock-update-\(UUID().uuidString).command")
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            showHomebrewFallback(brewPath: brewPath)
            return
        }
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            showHomebrewFallback(brewPath: brewPath)
            return
        }
        NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            Task { @MainActor in
                if error != nil { self?.showHomebrewFallback(brewPath: brewPath) }
                else { NSApp.terminate(nil) }
            }
        }
    }

    private func showHomebrewFallback(brewPath: String) {
        closeWindow()
        showMessage(L10n.text("Could Not Open Terminal"),
                    L10n.text("Quit everyDock, then run these commands in Terminal:") +
                    "\n\n\(brewPath) update\n\(brewPath) upgrade --cask \(InstallMethod.caskFullName)")
    }

    private func showMessage(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L10n.text("OK"))
        NSApp.activate()
        alert.runModal()
    }
}
