import AppKit
import DockCore

final class DockPanel: NSPanel {
    let surface: DockSurface
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init(model: AppModel) {
        surface = DockSurface(model: model)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "everyDock"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        contentView = surface
    }
}

@MainActor final class DockCoordinator: NSObject {
    private let model: AppModel
    private let workArea: WindowWorkAreaController
    private var panels: [String: DockPanel] = [:]
    private var requestedFrames: [String: NSRect] = [:]
    private var refreshTimer: Timer?
    private var globalMouse: Any?
    private var localMouse: Any?
    private var pointerTimer: Timer?
    private var lastPointer = NSPoint(x: -100000, y: -100000)
    init(model: AppModel) {
        self.model = model
        workArea = WindowWorkAreaController(permissions: model.permissions)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screensChanged), name: name, object: nil)
        }
        model.onLayoutChanged = { [weak self] in self?.reconcile() }
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated { self?.updatePointer(event: event) }
        }
        localMouse = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.updatePointer(event: event)
            return event
        }
        let timer = Timer(timeInterval: 5, target: self, selector: #selector(refreshGeometry), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = 1
        refreshTimer = timer
        // Also catch pointer warps (remote control, display changes) that emit no mouseMoved event.
        let pointer = Timer(timeInterval: 0.05, target: self, selector: #selector(checkPointer), userInfo: nil, repeats: true)
        RunLoop.main.add(pointer, forMode: .common)
        pointerTimer = pointer
        screensChanged()
    }
    @objc private func screensChanged() {
        model.updateDisplays()
        model.updateNativeDock()
        reconcile()
    }
    private func updatePointer(event: NSEvent? = nil) {
        let location: NSPoint
        if let event, let window = event.window {
            location = window.convertPoint(toScreen: event.locationInWindow)
        } else if let point = event?.cgEvent?.location {
            location = NSPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
        } else { location = NSEvent.mouseLocation }
        lastPointer = location
        panels.values.forEach { $0.surface.updatePointer(at: location) }
    }
    @objc private func checkPointer() {
        let point = NSEvent.mouseLocation
        guard point != lastPointer else { return }
        lastPointer = point
        updatePointer()
    }
    @objc private func refreshGeometry() { reconcile(raise: false) }
    func reconcile(raise: Bool = true) {
        var areas: [WindowWorkArea] = []
        let originY = NSScreen.screens.first?.frame.maxY ?? 0
        let visible = NSScreen.screens.filter { !model.preferences.hiddenDisplayIDs.contains(AppModel.displayID($0)) }
        let desiredIDs = Set(visible.map { AppModel.displayID($0) })
        for id in Array(panels.keys) where !desiredIDs.contains(id) {
            panels[id]?.surface.shutdown()
            panels.removeValue(forKey: id)?.close()
            requestedFrames.removeValue(forKey: id)
        }
        for screen in visible {
            let id = AppModel.displayID(screen)
            let panel = panels[id] ?? DockPanel(model: model)
            panels[id] = panel
            var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            if model.preferences.showOnFullScreen { behavior.formUnion([.fullScreenAuxiliary, .canJoinAllApplications]) }
            else { behavior.insert(.fullScreenNone) }
            if panel.collectionBehavior != behavior { panel.collectionBehavior = behavior }
            let pref = model.preferences
            var area = screen.visibleFrame
            if model.nativeDockManaged {
                area = NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width,
                              height: screen.visibleFrame.maxY - screen.frame.minY)
            }
            let horizontal = pref.edge == .bottom
            let inset = model.edgeInset
            let available = (horizontal ? area.width : area.height) - inset * 2
            let baseLength = DockMetrics.length(iconSize: model.iconSize, appCount: model.apps.count)
            let reserve = DockMetrics.reserve(iconSize: model.iconSize, magnification: model.magnification)
            let length = min(available, baseLength + reserve)
            let thickness = min(horizontal ? area.height : area.width, model.iconSize * model.magnification + model.iconSize * 0.45 + 56)
            let frame: NSRect
            switch pref.edge {
            case .bottom: frame = NSRect(x: area.midX - length / 2, y: area.minY + inset, width: length, height: thickness)
            case .left: frame = NSRect(x: area.minX + inset, y: area.midY - length / 2, width: thickness, height: length)
            case .right: frame = NSRect(x: area.maxX - inset - thickness, y: area.midY - length / 2, width: thickness, height: length)
            }
            let aligned = DockMetrics.aligned(frame, scale: screen.backingScaleFactor)
            if !model.paused {
                // Reserve the resting Dock, not its transparent magnification/tooltip space.
                let thickness = DockMetrics.thickness(iconSize: model.iconSize) + 4
                let boundary: Double
                switch pref.edge {
                case .bottom: boundary = originY - (aligned.minY + thickness)
                case .left: boundary = aligned.minX + thickness
                case .right: boundary = aligned.maxX - thickness
                }
                let visibleAX = CGRect(x: screen.visibleFrame.minX, y: originY - screen.visibleFrame.maxY,
                                       width: screen.visibleFrame.width, height: screen.visibleFrame.height)
                areas.append(WindowWorkArea(visible: visibleAX, dockBoundary: boundary, edge: pref.edge))
            }
            if requestedFrames[id] != aligned {
                requestedFrames[id] = aligned
                panel.setFrame(aligned, display: true)
                panel.surface.synchronize()
            }
            if model.paused { panel.orderOut(nil); panel.surface.shutdown() }
            else if raise || !panel.isVisible { panel.orderFrontRegardless() }
            panel.surface.updatePointer()
        }
        workArea.configure(areas)
    }
    func stop() {
        workArea.stop()
        refreshTimer?.invalidate()
        pointerTimer?.invalidate()
        if let globalMouse { NSEvent.removeMonitor(globalMouse) }
        if let localMouse { NSEvent.removeMonitor(localMouse) }
        panels.values.forEach { $0.surface.shutdown(); $0.close() }
        panels.removeAll()
    }
}
