// Manual AX integration fixture. Uses no files, preferences, network, or real documents.
// Build/run instructions: docs/QA-v0.3.2.md.
import AppKit

@MainActor final class Fixture: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windows: [NSWindow] = []
    var confirmsClose = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        for index in 0..<3 {
            let window = NSWindow(contentRect: NSRect(x: 100 + index * 140, y: 220 + index * 60, width: 420, height: 240),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "everyDock Test Window"
            window.delegate = self
            window.isReleasedWhenClosed = false
            let label = NSTextField(labelWithString: "Disposable test window \(index + 1) — no user files")
            label.frame = NSRect(x: 20, y: 170, width: 380, height: 24)
            window.contentView?.addSubview(label)
            let toggle = NSButton(checkboxWithTitle: "Require save confirmation for all test windows", target: self, action: #selector(toggleConfirmation(_:)))
            toggle.frame = NSRect(x: 20, y: 100, width: 390, height: 30)
            window.contentView?.addSubview(toggle)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func toggleConfirmation(_ sender: NSButton) { confirmsClose = sender.state == .on }
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Mark Test Window", action: #selector(markWindow), keyEquivalent: "").target = self
        let disabled = menu.addItem(withTitle: "Disabled Test Command", action: #selector(markWindow), keyEquivalent: "")
        disabled.target = self
        disabled.isEnabled = false
        let parent = menu.addItem(withTitle: "Nested Test Menu", action: nil, keyEquivalent: "")
        let nested = NSMenu()
        nested.addItem(withTitle: "Mark Nested Test Window", action: #selector(markNestedWindow), keyEquivalent: "").target = self
        parent.submenu = nested
        return menu
    }
    @objc func markWindow() { windows.last?.title = "Dock menu command received" }
    @objc func markNestedWindow() { windows.last?.title = "Nested Dock menu command received" }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard confirmsClose else { return true }
        let alert = NSAlert()
        alert.messageText = "Test save confirmation"
        alert.informativeText = "No real document exists. Cancel must preserve this window and stop close-all."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Close Test Window")
        alert.beginSheetModal(for: sender) { response in
            if response == .alertSecondButtonReturn { sender.close() }
        }
        return false
    }
}
@main struct FixtureMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let fixture = Fixture()
        app.delegate = fixture
        app.setActivationPolicy(.regular)
        withExtendedLifetime(fixture) { app.run() }
    }
}
