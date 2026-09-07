import AppKit
import SwiftUI

#if !arch(arm64)
#error("everyDock supports Apple Silicon only.")
#endif

@main
enum EveryDockApp {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
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
    private var pauseItem: NSMenuItem!

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
        coordinator = DockCoordinator(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "everyDock")
        statusItem.button?.toolTip = "everyDock — 모든 화면의 Dock"
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "everyDock 설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "앱 추가…", action: #selector(addApps), keyEquivalent: "").target = self
        menu.addItem(.separator())
        pauseItem = menu.addItem(withTitle: "모든 Dock 일시 숨기기", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(withTitle: "디스플레이 다시 감지", action: #selector(refreshDisplays), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "everyDock 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        if !UserDefaults.standard.bool(forKey: "everyDock.hasLaunched") {
            UserDefaults.standard.set(true, forKey: "everyDock.hasLaunched")
            openSettings()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        pauseItem.title = model.paused ? "모든 Dock 다시 표시" : "모든 Dock 일시 숨기기"
    }

    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "everyDock")
        appMenu.addItem(withTitle: "everyDock 설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "everyDock 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "편집")
        edit.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "모두 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        let windowItem = NSMenuItem()
        let windows = NSMenu(title: "윈도우")
        windows.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windows.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windows
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windows
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "everyDock 설정"
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

    @objc private func addApps() { model.chooseApps() }
    @objc private func togglePause() { model.paused.toggle() }
    @objc private func refreshDisplays() { model.updateDisplays(); coordinator.reconcile() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { coordinator?.stop(); model?.stop() }
}
