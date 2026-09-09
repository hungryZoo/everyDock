import AppKit
import ApplicationServices
import Combine
import DockCore

private let workAreaEvent = Notification.Name("everyDock.workAreaEvent")
private struct ObservedWindowEvent: Sendable {
    let window: WindowReference
    let created: Bool
}
private final class WindowObservation: @unchecked Sendable {
    let observer: AXObserver
    init(_ observer: AXObserver) { self.observer = observer }
    static func make(pid: pid_t) -> WindowObservation? {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.25)
        var observer: AXObserver?
        let error = AXObserverCreate(pid, { _, element, notification, _ in
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            let event = ObservedWindowEvent(window: WindowReference(pid: pid, element: element), created: notification as String == kAXWindowCreatedNotification)
            Task { @MainActor in NotificationCenter.default.post(name: workAreaEvent, object: event) }
        }, &observer)
        guard error == .success, let observer else { return nil }
        // Some applications deliver resize at application scope, others require each window.
        AXObserverAddNotification(observer, application, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, application, kAXWindowResizedNotification as CFString, nil)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success else { return nil }
        for window in value as? [AXUIElement] ?? [] {
            let result = AXObserverAddNotification(observer, window, kAXWindowResizedNotification as CFString, nil)
            WindowTrace.write("resize observer status=\(result.rawValue)")
        }
        return WindowObservation(observer)
    }
}

/// One frontmost application observer, no window polling or rendering-thread AX calls.
@MainActor final class WindowWorkAreaController: NSObject {
    private let permissions: AppPermissions
    private var areas: [WindowWorkArea] = []
    private var observation: WindowObservation?
    private var installing: Task<Void, Never>?
    private var pending: [WindowReference: Task<Void, Never>] = [:]
    private var activePID: pid_t?
    private var lastAttempt: [WindowReference: TimeInterval] = [:]
    private var permissionSubscription: AnyCancellable?
    private var generation = 0
    init(permissions: AppPermissions) {
        self.permissions = permissions
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changed(_:)), name: workAreaEvent, object: nil)
        permissionSubscription = permissions.$accessibility.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor in self?.observeFrontmost(force: true) }
        }
    }
    func configure(_ areas: [WindowWorkArea]) {
        guard self.areas != areas else { return }
        self.areas = areas
        observeFrontmost(force: true)
    }
    @objc private func activated() { observeFrontmost(force: false) }
    private func observeFrontmost(force: Bool) {
        let process = NSWorkspace.shared.frontmostApplication
        let pid = process?.processIdentifier
        if !force, activePID == pid, observation != nil { return }
        disconnect()
        guard !areas.isEmpty, permissions.accessibility != .denied, let pid,
              pid != ProcessInfo.processInfo.processIdentifier else { return }
        activePID = pid
        let current = generation
        installing = Task { @MainActor in
            let token = await Task.detached(priority: .utility) { WindowObservation.make(pid: pid) }.value
            guard !Task.isCancelled, current == generation, let token else { return }
            observation = token
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(token.observer), .commonModes)
        }
    }
    @objc private func changed(_ notification: Notification) {
        guard let event = notification.object as? ObservedWindowEvent, event.window.pid == activePID else { return }
        if event.created { observeFrontmost(force: true); return }
        WindowTrace.write("resize event")
        pending[event.window]?.cancel()
        let current = generation
        pending[event.window] = Task { @MainActor in
            // Let the application's zoom animation finish before issuing one correction.
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, current == generation else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - (lastAttempt[event.window] ?? 0) > 0.5 else { pending[event.window] = nil; return }
            lastAttempt[event.window] = now
            let failure = await WindowActions.fitZoomedWindow(event.window, areas: areas)
            guard !Task.isCancelled, current == generation else { return }
            pending[event.window] = nil
            if let failure { permissions.recordAccessibility(failure) }
        }
    }
    private func disconnect() {
        generation += 1
        installing?.cancel(); installing = nil
        pending.values.forEach { $0.cancel() }; pending.removeAll()
        lastAttempt.removeAll()
        if let observation { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observation.observer), .commonModes) }
        observation = nil; activePID = nil
    }
    func stop() {
        areas = []; disconnect(); permissionSubscription?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
