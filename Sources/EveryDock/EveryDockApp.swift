import AppKit
import SwiftUI
import Combine
import DockCore
import Carbon

#if !arch(arm64)
#error("everyDock supports Apple Silicon only.")
#endif

@main
enum EveryDockApp {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        let saved = UserDefaults.standard.data(forKey: "everyDock.preferences.v1")
            .flatMap { try? JSONDecoder().decode(DockPreferences.self, from: $0) }
        L10n.use(saved?.language ?? .system)
        if arguments == [arguments[0], "--reset-for-uninstall"] {
            do { try UninstallCleanup.run(); exit(0) }
            catch { fputs("everyDock cleanup failed: \(error.localizedDescription)\n", stderr); exit(1) }
        }
        if arguments.count == 4, arguments[1] == "--dock-watchdog", let pid = Int32(arguments[2]) {
            NativeDockManager.runWatchdog(parent: pid, journal: URL(fileURLWithPath: arguments[3]))
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var coordinator: DockCoordinator!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var statusObservation: AnyCancellable?
    private var pauseItem: NSMenuItem!
    private var launchPermissionCheck: Task<Void, Never>?
    private var permissionGuideDismissed = false
    private var terminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening the app should not produce a second set of Dock panels.
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        model = AppModel()
        installMainMenu()
        model.showSettings = { [weak self] in self?.openSettings() }
        model.showOnboarding = { [weak self] in self?.openOnboarding() }
        coordinator = DockCoordinator(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "everyDock")
        installStatusMenu()
        model.onLanguageChanged = { [weak self] in self?.refreshLanguage() }
        statusObservation = model.$preferences.map(\.hideMenuBarIcon).removeDuplicates().sink { [weak self] hidden in
            self?.statusItem.isVisible = !hidden
        }
        let event = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
            || event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue == true
        switch StartupPresentation.resolve(hasLaunched: UserDefaults.standard.bool(forKey: "everyDock.hasLaunched"),
                                           loginLaunch: loginLaunch, hidesMenuIcon: model.preferences.hideMenuBarIcon,
                                           needsPermissionGuidance: model.permissions.needsGuidance) {
        case .onboarding: openOnboarding()
        case .settings: openSettings()
        case .background: break
        }
        checkLaunchPermissions()
    }

    private func installStatusMenu() {
        statusItem.button?.toolTip = L10n.text("everyDock — A Dock on every display")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: L10n.text("everyDock Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L10n.text("Add Apps…"), action: #selector(addApps), keyEquivalent: "").target = self
        menu.addItem(.separator())
        pauseItem = menu.addItem(withTitle: L10n.text("Hide All Docks"), action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(withTitle: L10n.text("Detect Displays Again"), action: #selector(refreshDisplays), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.text("Quit everyDock"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        let inactive = NSMenuItem(title: L10n.text("Paused — using macOS Dock until an external display is connected."), action: nil, keyEquivalent: "")
        inactive.tag = 101
        inactive.isHidden = !model.automaticallyPaused
        menu.insertItem(inactive, at: 0)
    }

    private func refreshLanguage() {
        installMainMenu()
        installStatusMenu()
        settingsWindow?.title = L10n.text("everyDock Settings")
        onboardingWindow?.title = L10n.text("Welcome to everyDock")
        coordinator.refreshLanguage()
    }

    private func checkLaunchPermissions() {
        guard launchPermissionCheck == nil else { return }
        permissionGuideDismissed = false
        launchPermissionCheck = Task { @MainActor [weak self] in
            guard let self else { return }
            let slowCheck = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self, model.permissions.checking else { return }
                if !permissionGuideDismissed && onboardingWindow?.isVisible != true { openOnboarding() }
            }
            await model.permissions.recheck()
            slowCheck.cancel()
            if !permissionGuideDismissed && model.permissions.needsGuidance && onboardingWindow?.isVisible != true { openOnboarding() }
            launchPermissionCheck = nil
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTag: 101)?.isHidden = !model.automaticallyPaused
        pauseItem.title = model.paused ? L10n.text("Show All Docks") : L10n.text("Hide All Docks")
    }

    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "everyDock")
        appMenu.addItem(withTitle: L10n.text("everyDock Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("Quit everyDock"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: L10n.text("Edit"))
        edit.addItem(withTitle: L10n.text("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L10n.text("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L10n.text("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L10n.text("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        let windowItem = NSMenuItem()
        let windows = NSMenu(title: L10n.text("Window"))
        windows.addItem(withTitle: L10n.text("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windows.addItem(withTitle: L10n.text("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windows
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windows
    }

    @objc private func openSettings() {
        model.refreshApps(force: true)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = L10n.text("everyDock Settings")
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.minSize = NSSize(width: 540, height: 620)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("everyDock.settings")
            window.center()
            settingsWindow = window
        }
        model.refreshLoginStatus()
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func openOnboarding() {
        model.refreshLoginStatus()
        model.permissions.refreshHints()
        if onboardingWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 620),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = L10n.text("Welcome to everyDock")
            window.minSize = NSSize(width: 540, height: 520)
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        onboardingWindow?.contentView = NSHostingView(rootView: OnboardingView(model: model,
            firstLaunch: !UserDefaults.standard.bool(forKey: "everyDock.hasLaunched")) { [weak self] in
                UserDefaults.standard.set(true, forKey: "everyDock.hasLaunched")
                self?.permissionGuideDismissed = true
                self?.onboardingWindow?.close()
            })
        NSApp.activate()
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func addApps() { model.chooseApps() }
    @objc private func togglePause() { model.paused.toggle() }
    @objc private func refreshDisplays() { model.updateDisplays(); coordinator.reconcile() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        checkLaunchPermissions()
        if let onboardingWindow, onboardingWindow.isVisible {
            NSApp.activate()
            onboardingWindow.makeKeyAndOrderFront(nil)
            return false
        }
        if model.permissions.needsGuidance { openOnboarding() }
        else { openSettings() }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if !terminationPending {
            terminationPending = true
            Task { @MainActor in
                await model.finishPinSynchronization()
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) { launchPermissionCheck?.cancel(); coordinator?.stop(); model?.stop() }
}
