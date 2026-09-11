import AppKit
import Combine
import DockCore
import QuartzCore

@MainActor final class DockSurface: NSView {
    private let model: AppModel
    private let glass = NSGlassEffectView()
    private let indicators = DockIndicators()
    private let tooltip = DockTooltip(frame: .zero)
    private var menuTracking = false
    private let menuButton = NSButton()
    private var buttons: [String: DockAppButton] = [:]
    private var utilityButtons: [DockUtility: DockUtilityButton] = [:]
    private let previews: WindowPreviewController
    private var observation: AnyCancellable?
    private var scales: [String: Double] = [:]
    private var launches: [String: TimeInterval] = [:]
    private var clicks: [String: TimeInterval] = [:]
    private let frameTrace = FrameTrace()
    private var displayLink: CADisplayLink?
    private var synchronizationPending = false
    private var edge: DockEdge = .bottom
    private var magnification = 1.0
    private var reduceMotion = false
    private var itemIDs: [String] = []
    private var hoverPoint: NSPoint?
    private let debugPointer = ProcessInfo.processInfo.environment["EVERYDOCK_DEBUG_POINTER"] == "1"
    private var lastDiagnosticPoint: NSPoint?
    private var backgroundRect = NSRect.zero
    private var scrollIndex = 0
    private var baseSize = 48.0
    private var visibleApps: [DockApplication] = []
    private var separatorIDs = Set<String>()
    private var runningBoundary: Int?
    private var insertionIndex: Int?
    private let dropIndicator = CALayer()
    private let dropHint = DockTooltip(frame: .zero)
    private enum DropAction { case insert(Int), unpin }
    private var dropAction: DropAction?
    static let reorderType = NSPasteboard.PasteboardType("app.everydock.pinned-item")
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var horizontal: Bool { edge == .bottom }

    init(model: AppModel) {
        self.model = model
        previews = WindowPreviewController(model: model)
        super.init(frame: .zero)
        previews.onVisibilityChange = { [weak self] shown in
            if shown { self?.tooltip.isHidden = true }
        }
        wantsLayer = true
        glass.style = .regular
        glass.contentView = NSView()
        glass.cornerRadius = 16
        addSubview(glass)
        addSubview(indicators)
        dropIndicator.backgroundColor = NSColor.controlAccentColor.cgColor
        dropIndicator.cornerRadius = 1
        dropIndicator.isHidden = true
        indicators.layer?.addSublayer(dropIndicator)
        tooltip.isHidden = true
        tooltip.setAccessibilityElement(false)
        addSubview(tooltip)
        dropHint.isHidden = true
        dropHint.setAccessibilityElement(false)
        addSubview(dropHint)
        menuButton.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "everyDock Menu")
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(showDockMenu)
        menuButton.toolTip = "everyDock Menu"
        menuButton.setAccessibilityLabel("everyDock Menu")
        // Dock controls live in the menu bar and the Dock background's contextual menu.
        for item in DockUtility.allCases {
            let button = DockUtilityButton(item: item, model: model)
            utilityButtons[item] = button
            addSubview(button, positioned: .below, relativeTo: tooltip)
        }
        registerForDraggedTypes([.fileURL, Self.reorderType])
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(synchronize), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("everyDock")
        observation = model.dockDidChange.sink { [weak self] in
            guard let self, !self.synchronizationPending else { return }
            self.synchronizationPending = true
            DispatchQueue.main.async { [weak self] in
                self?.synchronizationPending = false
                self?.synchronize()
            }
        }
        synchronize()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func synchronize() {
        guard !menuTracking else { synchronizationPending = true; return }
        guard !DockAppButton.isReordering else { return }
        edge = model.preferences.edge
        magnification = model.magnification
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !model.preferences.showPreviews { previews.close() }
        for (item, button) in utilityButtons {
            button.setArtwork(model.utilities.icon(item))
            if item == .desktop {
                let title = item.title
                button.toolTip = title
                button.setAccessibilityLabel(title)
            }
        }
        let ids = Set(model.apps.map(\.id))
        for id in Array(buttons.keys) where !ids.contains(id) {
            buttons.removeValue(forKey: id)?.removeFromSuperview()
            scales.removeValue(forKey: id)
            launches.removeValue(forKey: id)
        }
        for app in model.apps {
            let button = buttons[app.id] ?? DockAppButton(app: app, model: model)
            if button.superview == nil { addSubview(button, positioned: .below, relativeTo: tooltip) }
            button.app = app
            button.target = self
            button.action = #selector(appClicked(_:))
            if !app.isSeparator { button.setArtwork(app.icon) }
            button.setAccessibilityValue(app.isLaunching ? "Launching…" : app.isHidden ? "Hidden" : app.isActive ? "Active" : app.isRunning ? "Running" : "Not Running")
            buttons[app.id] = button
            if app.isLaunching && launches[app.id] == nil { launches[app.id] = ProcessInfo.processInfo.systemUptime }
            if !app.isLaunching { launches.removeValue(forKey: app.id) }
        }
        updateVisibleApps()
        animate()
    }

    private func updateVisibleApps() {
        let length = horizontal ? bounds.width : bounds.height
        guard length > 0 else { return }
        let reserve = DockMetrics.reserve(iconSize: model.iconSize, magnification: model.magnification)
        let customCount = model.apps.filter(\.isSeparator).count
        let separatesRunning = model.apps.contains { $0.isPinned && !$0.isSeparator } && model.apps.contains { !$0.isPinned }
        let usable = max(20, length - DockMetrics.padding * 2 - DockMetrics.separatorSpace * (separatesRunning ? 2 : 1) - reserve)
        let fixed = Double(customCount) * (DockMetrics.separatorSpace + DockMetrics.gap)
        baseSize = min(model.iconSize, max(20, (usable - fixed + DockMetrics.gap) / Double(max(1, model.apps.count - customCount + 3)) - DockMetrics.gap))
        let fullLength = DockMetrics.length(iconSize: baseSize, appCount: model.apps.count - customCount,
                                            customSeparators: customCount, runningBoundary: separatesRunning)
        if fullLength + reserve <= length + 0.1 { scrollIndex = 0 }
        scrollIndex = min(scrollIndex, max(0, model.apps.count - 1))
        visibleApps = []
        var remaining = usable - Double(3) * (baseSize + DockMetrics.gap) + DockMetrics.gap
        for app in model.apps.dropFirst(scrollIndex) {
            let width = (app.isSeparator ? DockMetrics.separatorSpace : baseSize) + DockMetrics.gap
            guard remaining >= width - 0.1 else { break }
            visibleApps.append(app)
            remaining -= width
        }
        separatorIDs = Set(visibleApps.filter(\.isSeparator).map(\.id))
        runningBoundary = visibleApps.firstIndex { !$0.isPinned }
        if let boundary = runningBoundary, !visibleApps[..<boundary].contains(where: { !$0.isSeparator }) { runningBoundary = nil }
        itemIDs = visibleApps.map(\.id) + DockUtility.allCases.map { "utility.\($0.rawValue)" }
        let visibleIDs = Set(visibleApps.map(\.id))
        buttons.forEach { $0.value.isHidden = !visibleIDs.contains($0.key) }
        menuButton.toolTip = model.apps.count > visibleApps.count ? "everyDock Menu · Scroll to see more apps" : "everyDock Menu"
    }

    func updatePointer(at location: NSPoint? = nil) {
        if DockAppButton.isReordering {
            prepareForReorder()
            window?.ignoresMouseEvents = false
            return
        }
        guard !menuTracking else { return }
        guard let window, window.isVisible, !model.paused else { hoverPoint = nil; return }
        let point = convert(window.convertPoint(fromScreen: location ?? NSEvent.mouseLocation), from: nil)
        let onDock = backgroundRect.contains(point) || buttons.values.contains { !$0.isHidden && $0.frame.contains(point) }
            || utilityButtons.values.contains { $0.frame.contains(point) }
        let hovered = visibleApps.first { !$0.isSeparator && buttons[$0.id]?.frame.contains(point) == true }
        previews.update(app: onDock ? hovered : nil, anchor: hovered.flatMap { buttons[$0.id] }, screenPoint: location ?? NSEvent.mouseLocation)
        if debugPointer, point != lastDiagnosticPoint {
            lastDiagnosticPoint = point
            let line = "pointer screen=\(NSEvent.mouseLocation) window=\(window.frame) local=\(point) bar=\(backgroundRect) hit=\(onDock)\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
        // Transparent animation space passes clicks through to the user's other windows.
        let acceptsInput = onDock || DockIconButton.trackingButton != nil
        if window.ignoresMouseEvents == acceptsInput { window.ignoresMouseEvents = !acceptsInput }
        let next = onDock ? point : nil
        if next != hoverPoint { hoverPoint = next; animate() }
    }

    private func animate() {
        guard !menuTracking, displayLink == nil, window != nil else { return }
        lastTick = CACurrentMediaTime()
        let link = displayLink(target: self, selector: #selector(displayTick(_:)))
        let rate = Float(window?.screen?.maximumFramesPerSecond ?? 60)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, rate), maximum: rate, preferred: rate)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayTick(_ link: CADisplayLink) {
        let start = frameTrace.begin(timestamp: link.timestamp, interval: link.targetTimestamp - link.timestamp)
        tick(at: link.targetTimestamp)
        frameTrace.end(start: start)
        if displayLink == nil { frameTrace.flush() }
    }

    private func tick(at now: TimeInterval) {
        guard bounds.width > 0, bounds.height > 0 else { stop(); return }
        let interpolation = reduceMotion ? 1.0 : DockMotion.interpolation(elapsed: now - lastTick)
        lastTick = now
        let length = horizontal ? bounds.width : bounds.height
        let allIDs = itemIDs
        let baselineLength = DockMetrics.length(iconSize: baseSize, appCount: visibleApps.count - separatorIDs.count,
                                                customSeparators: separatorIDs.count, runningBoundary: runningBoundary != nil)
        let baselineStart = (length - baselineLength) / 2 + DockMetrics.padding
        let pointerAxis = hoverPoint.map { horizontal ? $0.x : bounds.height - $0.y }
        var needsAnotherFrame = false
        var sizes: [Double] = []
        var baselineCursor = baselineStart
        for (index, id) in allIDs.enumerated() {
            if index == runningBoundary || index == visibleApps.count { baselineCursor += DockMetrics.separatorSpace }
            if separatorIDs.contains(id) {
                sizes.append(DockMetrics.separatorSpace)
                baselineCursor += DockMetrics.separatorSpace + DockMetrics.gap
                continue
            }
            let center = baselineCursor + baseSize / 2
            baselineCursor += baseSize + DockMetrics.gap
            let target = pointerAxis.map { DockMotion.scale(distance: $0 - center, iconSize: baseSize,
                                                           magnification: magnification) } ?? 1
            let previous = scales[id] ?? 1
            let scale = abs(target - previous) < 0.001 ? target : previous + (target - previous) * interpolation
            scales[id] = scale
            needsAnotherFrame = needsAnotherFrame || abs(target - scale) > 0.001
            sizes.append(baseSize * scale)
        }
        let total = sizes.reduce(0, +) + Double(max(0, sizes.count - 1)) * DockMetrics.gap + DockMetrics.padding * 2 + DockMetrics.separatorSpace * (runningBoundary == nil ? 1 : 2)
        var cursor = (length - total) / 2 + DockMetrics.padding
        let thickness = DockMetrics.thickness(iconSize: baseSize)
        backgroundRect = orientedRect(axis: (length - total) / 2, inward: 0, length: total, thickness: thickness)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if glass.frame != backgroundRect { glass.frame = backgroundRect }
        if glass.cornerRadius != thickness * 0.28 { glass.cornerRadius = thickness * 0.28 }
        if indicators.frame != bounds { indicators.frame = bounds }
        indicators.dots.removeAll(keepingCapacity: true)
        indicators.separators.removeAll(keepingCapacity: true)
        func separator(at axis: Double) {
            indicators.separators.append(orientedRect(axis: axis, inward: 10, length: 0.5, thickness: max(10, thickness - 20)))
        }
        for (index, app) in visibleApps.enumerated() {
            if index == runningBoundary {
                separator(at: cursor + DockMetrics.separatorSpace / 2)
                cursor += DockMetrics.separatorSpace
            }
            let size = sizes[index]
            if app.isSeparator {
                buttons[app.id]?.frame = orientedRect(axis: cursor, inward: 0, length: size, thickness: thickness)
                separator(at: cursor + size / 2)
                cursor += size + DockMetrics.gap
                continue
            }
            var bounce = 0.0
            if !reduceMotion, !DockAppButton.isReordering, let start = launches[app.id] {
                bounce = DockMotion.bounce(elapsed: now - start, iconSize: baseSize)
                needsAnotherFrame = true
            } else if !reduceMotion, !DockAppButton.isReordering, let start = clicks[app.id], now - start < 0.3 {
                bounce = sin((now - start) / 0.3 * .pi) * 5
                needsAnotherFrame = true
            } else { clicks.removeValue(forKey: app.id) }
            buttons[app.id]?.frame = orientedRect(axis: cursor, inward: DockMetrics.iconBaseline + bounce, length: size, thickness: size)
            if app.isRunning || app.isLaunching {
                indicators.dots.append((orientedRect(axis: cursor + size / 2 - 1.5, inward: 3, length: 3, thickness: 3), app.isActive))
            }
            cursor += size + DockMetrics.gap
        }
        separator(at: cursor + DockMetrics.separatorSpace / 2)
        cursor += DockMetrics.separatorSpace
        for (index, item) in DockUtility.allCases.enumerated() {
            let size = sizes[visibleApps.count + index]
            utilityButtons[item]?.frame = orientedRect(axis: cursor, inward: DockMetrics.iconBaseline, length: size, thickness: size)
            cursor += size + DockMetrics.gap
        }
        indicators.apply()
        let hovered = hoverPoint.flatMap { point in visibleApps.first { !$0.isSeparator && buttons[$0.id]?.frame.contains(point) == true } }
        if let hovered, let button = buttons[hovered.id] {
            let title = hovered.name + (hovered.isLaunching ? " — Launching…" : "")
            if tooltip.stringValue != title { tooltip.stringValue = title }
            let width = tooltip.intrinsicContentSize.width + 18
            let height = 26.0
            switch edge {
            case .bottom:
                tooltip.frame = NSRect(x: min(bounds.width - width, max(0, button.frame.midX - width / 2)), y: button.frame.maxY + 10, width: width, height: height)
            case .left:
                tooltip.frame = NSRect(x: button.frame.maxX + 10, y: button.frame.midY - height / 2, width: max(1, min(width, bounds.maxX - button.frame.maxX - 10)), height: height)
            case .right:
                tooltip.frame = NSRect(x: max(0, button.frame.minX - width - 10), y: button.frame.midY - height / 2, width: max(1, min(width, button.frame.minX - 10)), height: height)
            }
            tooltip.isHidden = previews.isShown
        } else { tooltip.isHidden = true }
        CATransaction.commit()
        if !needsAnotherFrame { stop() }
    }

    private func orientedRect(axis: Double, inward: Double, length: Double, thickness: Double) -> NSRect {
        switch edge {
        case .bottom: NSRect(x: axis, y: inward, width: length, height: thickness)
        case .left: NSRect(x: inward, y: bounds.height - axis - length, width: thickness, height: length)
        case .right: NSRect(x: bounds.width - inward - thickness, y: bounds.height - axis - length, width: thickness, height: length)
        }
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); synchronize() }
    override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize
        super.setFrameSize(newSize)
        if changed { updateVisibleApps(); animate() }
    }
    func stop() { displayLink?.invalidate(); displayLink = nil }
    func shutdown() { stop(); previews.close() }
    @objc private func appClicked(_ sender: DockAppButton) {
        guard !sender.app.isSeparator else { return }
        previews.close()
        clicks[sender.app.id] = ProcessInfo.processInfo.systemUptime
        model.launch(sender.app, anchor: sender)
        animate()
    }
    override func scrollWheel(with event: NSEvent) {
        guard !DockAppButton.isReordering else { return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        guard abs(delta) > 0.1 else { return }
        scrollIndex = max(0, scrollIndex + (delta < 0 ? 1 : -1))
        updateVisibleApps()
        animate()
    }
    @objc private func showDockMenu() {
        let menu = NSMenu()
        add(menu, "Add Apps…", #selector(addApps))
        add(menu, "Settings…", #selector(settings))
        menu.addItem(.separator())
        add(menu, "Hide All Docks", #selector(pause))
        add(menu, "Quit everyDock", #selector(quit))
        presentMenu(menu, anchor: self)
    }
    func presentMenu(_ menu: NSMenu, anchor: NSView) {
        guard let window, let screen = window.screen else { return }
        menuTracking = true
        previews.close()
        tooltip.isHidden = true
        stop()
        defer {
            menuTracking = false
            if synchronizationPending { synchronizationPending = false; synchronize() }
            updatePointer()
            animate()
        }
        menu.update()
        let rect = anchor === self ? backgroundRect : convert(anchor.bounds, from: anchor)
        let screenRect = window.convertToScreen(convert(rect, to: nil))
        let point = DockMenuPlacement.topLeft(anchor: screenRect, menu: menu.size, edge: edge, screen: screen.visibleFrame)
        menu.popUp(positioning: nil, at: point, in: nil)
    }
    func showWindows(_ button: DockAppButton) {
        // Start after NSMenu has finished tracking and released its mouse capture.
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button, button.window != nil else { return }
            previews.showImmediately(app: button.app, anchor: button)
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let axis = horizontal ? point.x : bounds.height - point.y
        let pins = visibleApps.filter(\.isPinned)
        let next = pins.first { app in
            guard let frame = buttons[app.id]?.frame else { return false }
            return axis < (horizontal ? frame.midX : bounds.height - frame.midY)
        }
        insertionIndex = next.flatMap { model.pinIndex($0) } ?? pins.last.flatMap { model.pinIndex($0).map { $0 + 1 } }
        if let last = pins.last, let frame = buttons[last.id]?.frame,
           axis > (horizontal ? frame.maxX : bounds.height - frame.minY) + DockMetrics.separatorSpace {
            insertionIndex = nil
        }
        let menu = NSMenu()
        if insertionIndex != nil {
            add(menu, "Add Separator Here", #selector(insertSeparator))
            menu.addItem(.separator())
        }
        add(menu, "Add Apps…", #selector(addApps))
        add(menu, "Settings…", #selector(settings))
        menu.addItem(.separator())
        add(menu, "Hide All Docks", #selector(pause))
        add(menu, "Quit everyDock", #selector(quit))
        presentMenu(menu, anchor: self)
    }
    @objc private func insertSeparator() { model.addSeparator(at: insertionIndex) }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self }
    @objc private func addApps() { model.chooseApps() }
    @objc private func settings() { model.showSettings?() }
    @objc private func pause() { model.paused = true }
    @objc private func quit() { NSApp.terminate(nil) }
    func prepareForReorder() {
        previews.close(); tooltip.isHidden = true; hoverPoint = nil; stop()
        if scales.values.contains(where: { abs($0 - 1) > 0.001 }) {
            scales.removeAll(keepingCapacity: true)
            tick(at: CACurrentMediaTime())
            stop()
        }
    }
    private func draggedApp(_ sender: any NSDraggingInfo) -> DockApplication? {
        guard let button = sender.draggingSource as? DockAppButton,
              button.belongs(to: model), button === DockAppButton.draggedButton,
              sender.draggingPasteboard.string(forType: Self.reorderType) == button.app.id,
              model.apps.contains(where: { $0.id == button.app.id }) else { return nil }
        return button.app
    }
    private func updateDrop(_ sender: any NSDraggingInfo) -> NSDragOperation {
        clearDrop()
        guard let dragged = draggedApp(sender) else { return [] }
        prepareForReorder()
        let point = convert(sender.draggingLocation, from: nil)
        let pins = visibleApps.filter(\.isPinned)
        let dropBounds = pins.reduce(backgroundRect) { rect, app in
            buttons[app.id].map { rect.union($0.frame) } ?? rect
        }
        // Magnified icons extend beyond the glass; their upper halves remain targets.
        guard dropBounds.insetBy(dx: -8, dy: -8).contains(point) else { return [] }
        let axis = horizontal ? point.x : bounds.height - point.y
        let utilityFrame = utilityButtons[.desktop]?.frame
        let utilityStart = utilityFrame.map { horizontal ? $0.minX : bounds.height - $0.maxY } ?? 0
        guard axis < utilityStart else { return [] }
        let firstOther = visibleApps.first { !$0.isPinned }.flatMap { buttons[$0.id]?.frame }
            ?? utilityFrame
        if let last = pins.last, let lastFrame = buttons[last.id]?.frame, let firstOther {
            let lastEnd = horizontal ? lastFrame.maxX : bounds.height - lastFrame.minY
            let nextStart = horizontal ? firstOther.minX : bounds.height - firstOther.maxY
            let boundary = (lastEnd + nextStart) / 2
            if axis >= boundary {
                guard dragged.isPinned, !dragged.isSeparator else { return [] }
                dropAction = .unpin
                showDropIndicator(at: boundary, color: .systemOrange)
                dropHint.stringValue = "Unpin from Dock"
                let width = dropHint.intrinsicContentSize.width + 18
                switch edge {
                case .bottom:
                    dropHint.frame = NSRect(x: min(bounds.width - width, max(0, point.x - width / 2)), y: backgroundRect.maxY + 10, width: width, height: 26)
                case .left:
                    dropHint.frame = NSRect(x: backgroundRect.maxX + 10, y: min(bounds.height - 26, max(0, point.y - 13)), width: min(width, max(1, bounds.width - backgroundRect.maxX - 10)), height: 26)
                case .right:
                    dropHint.frame = NSRect(x: max(0, backgroundRect.minX - width - 10), y: min(bounds.height - 26, max(0, point.y - 13)), width: min(width, max(1, backgroundRect.minX - 10)), height: 26)
                }
                dropHint.isHidden = false
                return .move
            }
        } else if let firstOther {
            let limit = horizontal ? firstOther.minX : bounds.height - firstOther.maxY
            guard axis <= limit else { return [] }
        }
        let next = pins.first { app in
            guard let frame = buttons[app.id]?.frame else { return false }
            return axis < (horizontal ? frame.midX : bounds.height - frame.midY)
        }
        let slot: Int
        let marker: Double
        if let next, let index = model.pinIndex(next), let frame = buttons[next.id]?.frame {
            slot = index
            marker = (horizontal ? frame.minX : bounds.height - frame.maxY) - DockMetrics.gap / 2
        } else if let last = pins.last, let index = model.pinIndex(last), let frame = buttons[last.id]?.frame {
            slot = index + 1
            marker = (horizontal ? frame.maxX : bounds.height - frame.minY) + DockMetrics.gap / 2
        } else {
            // An empty pinned area accepts a running app before the first app/folder.
            guard model.preferences.pinnedApps.isEmpty else { return [] }
            slot = 0
            marker = (horizontal ? backgroundRect.minX : bounds.height - backgroundRect.maxY) + DockMetrics.padding
        }
        dropAction = .insert(slot)
        showDropIndicator(at: marker, color: .controlAccentColor)
        return .move
    }
    private func showDropIndicator(at marker: Double, color: NSColor) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dropIndicator.backgroundColor = color.cgColor
        dropIndicator.frame = orientedRect(axis: marker - 1, inward: 5, length: 2, thickness: max(10, DockMetrics.thickness(iconSize: baseSize) - 10))
        dropIndicator.isHidden = false
        CATransaction.commit()
    }
    private func clearDrop() { dropAction = nil; dropIndicator.isHidden = true; dropHint.isHidden = true }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.availableType(from: [Self.reorderType]) != nil ? updateDrop(sender) : .copy
    }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: (any NSDraggingInfo)?) { clearDrop() }
    override func draggingEnded(_ sender: any NSDraggingInfo) { clearDrop() }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if sender.draggingPasteboard.availableType(from: [Self.reorderType]) != nil {
            guard updateDrop(sender) == .move, let action = dropAction, let app = draggedApp(sender) else { clearDrop(); return false }
            clearDrop()
            switch action {
            case .insert(let slot): model.movePin(app, toInsertionSlot: slot)
            case .unpin: model.unpinDraggedApp(app)
            }
            return true
        }
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let apps = urls.filter { $0.pathExtension.lowercased() == "app" }
        model.addApps(apps)
        return !apps.isEmpty
    }
}

private final class DockIndicators: NSView {
    var dots: [(NSRect, Bool)] = []
    var separators: [NSRect] = []
    private var dotLayers: [CALayer] = []
    private var separatorLayers: [CALayer] = []
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func apply() {
        while dotLayers.count < dots.count {
            let dot = CALayer()
            dot.cornerRadius = 1.5
            layer?.addSublayer(dot)
            dotLayers.append(dot)
        }
        for (index, dot) in dotLayers.enumerated() {
            dot.isHidden = index >= dots.count
            if index < dots.count {
                dot.frame = dots[index].0
                dot.backgroundColor = (dots[index].1 ? NSColor.labelColor : .secondaryLabelColor).cgColor
            }
        }
        while separatorLayers.count < separators.count {
            let line = CALayer(); layer?.addSublayer(line); separatorLayers.append(line)
        }
        for (index, line) in separatorLayers.enumerated() {
            line.isHidden = index >= separators.count
            if index < separators.count {
                line.frame = separators[index]
                line.backgroundColor = NSColor.separatorColor.cgColor
            }
        }
    }
}

/// Keep enough pixels for the maximum supported magnification, independent of animated bounds.
@MainActor class DockIconButton: NSControl {
    private(set) static weak var trackingButton: DockIconButton?
    private var artwork: NSImage?
    private var pixels: CGImage?
    private var artworkScale: CGFloat = 0
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .resizeAspect
        // Linear sampling skips fine details when a large texture shrinks to a resting icon.
        layer?.minificationFilter = .trilinear
        layer?.magnificationFilter = .linear
        setAccessibilityRole(.button)
        setAccessibilityElement(true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.contents = pixels }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshArtwork()
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        refreshArtwork()
    }
    func setArtwork(_ image: NSImage) {
        guard artwork !== image else { return }
        artwork = image
        refreshArtwork(force: true)
    }
    private func refreshArtwork(force: Bool = false) {
        guard let artwork else { return }
        let scale = window?.backingScaleFactor ?? 2
        guard force || artworkScale != scale else { return }
        // Preferences cap icon size at 72pt and magnification at 4×.
        let side = Int(ceil(72 * 4 * scale))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill(using: .copy)
        let aspect = artwork.size.width / max(1, artwork.size.height)
        let size = NSSize(width: aspect >= 1 ? CGFloat(side) : CGFloat(side) * aspect,
                          height: aspect >= 1 ? CGFloat(side) / aspect : CGFloat(side))
        artwork.draw(in: NSRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2,
                               width: size.width, height: size.height),
                     from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        pixels = bitmap.cgImage
        artworkScale = scale
        layer?.contentsScale = scale
        layer?.contents = pixels
    }
    private func highlight(_ flag: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.opacity = flag ? 0.6 : 1
        CATransaction.commit()
    }
    override func mouseDown(with event: NSEvent) {
        Self.trackingButton = self
        highlight(true)
    }
    func cancelTracking() {
        if Self.trackingButton === self { Self.trackingButton = nil }
        highlight(false)
    }
    override func mouseDragged(with event: NSEvent) {
        highlight(bounds.contains(convert(event.locationInWindow, from: nil)))
    }
    override func mouseUp(with event: NSEvent) {
        guard Self.trackingButton === self else { return }
        Self.trackingButton = nil
        highlight(false)
        if bounds.contains(convert(event.locationInWindow, from: nil)) { _ = sendAction(action, to: target) }
    }
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 { _ = sendAction(action, to: target) }
        else { super.keyDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool { sendAction(action, to: target) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor final class DockAppButton: DockIconButton, NSDraggingSource {
    private(set) static weak var draggedButton: DockAppButton?
    private static weak var commandButton: DockAppButton?
    static var isReordering: Bool { commandButton != nil || draggedButton != nil }
    private var commandDown: NSPoint?
    var app: DockApplication
    private let model: AppModel
    private var menuGeneration = 0
    init(app: DockApplication, model: AppModel) {
        self.app = app
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityLabel(app.name)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func rightMouseDown(with event: NSEvent) {
        showAppMenu()
    }
    override func accessibilityPerformShowMenu() -> Bool { showAppMenu(); return true }
    override func mouseDown(with event: NSEvent) {
        commandDown = nil
        if event.modifierFlags.contains(.control) { showAppMenu() }
        else if event.modifierFlags.contains(.command) {
            super.mouseDown(with: event)
            commandDown = event.locationInWindow
            Self.commandButton = self
            menuGeneration += 1
            (superview as? DockSurface)?.prepareForReorder()
        }
        else { super.mouseDown(with: event) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let origin = commandDown else { super.mouseDragged(with: event); return }
        guard hypot(event.locationInWindow.x - origin.x, event.locationInWindow.y - origin.y) >= 4 else { return }
        commandDown = nil
        Self.draggedButton = self
        cancelTracking()
        let data = NSPasteboardItem()
        data.setString(app.id, forType: DockSurface.reorderType)
        let item = NSDraggingItem(pasteboardWriter: data)
        let image = app.isSeparator ? NSImage(systemSymbolName: "line.diagonal", accessibilityDescription: "Separator")! : app.icon
        let point = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2, width: bounds.width, height: bounds.height), contents: image)
        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    override func mouseUp(with event: NSEvent) {
        if commandDown != nil { commandDown = nil; cancelTracking(); finishReorder(); return }
        super.mouseUp(with: event)
    }
    func belongs(to model: AppModel) -> Bool { self.model === model }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        finishReorder()
    }
    private func finishReorder() {
        Self.draggedButton = nil
        Self.commandButton = nil
        commandDown = nil
        // Refresh every screen once after drop/cancel; no preference writes during movement.
        model.dockDidChange.send()
        (superview as? DockSurface)?.synchronize()
        (superview as? DockSurface)?.updatePointer()
    }
    private func showAppMenu() {
        if app.isSeparator {
            let menu = NSMenu()
            add(menu, "Remove Separator", #selector(pin))
            add(menu, "Move Earlier", #selector(moveEarlier))
            add(menu, "Move Later", #selector(moveLater))
            (superview as? DockSurface)?.presentMenu(menu, anchor: self)
        }
        else if app.isRunning { readNativeMenu(path: []) }
        else { showFallbackMenu() }
    }
    private func showFallbackMenu(message: String? = nil) {
        menuGeneration += 1
        let menu = NSMenu(title: app.name)
        if let message {
            let notice = menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
            notice.isEnabled = false
            menu.addItem(.separator())
        }
        appendAppActions(to: menu)
        (superview as? DockSurface)?.presentMenu(menu, anchor: self)
    }
    private func appendAppActions(to menu: NSMenu) {
        add(menu, "Open", #selector(openApp))
        if app.isRunning {
            add(menu, "Show Windows…", #selector(showWindows))
            add(menu, "Close All Windows", #selector(closeWindows))
            menu.addItem(.separator())
        }
        add(menu, app.isPinned ? "Unpin from Dock" : "Pin to Dock", #selector(pin))
        if app.isPinned {
            add(menu, "Move Earlier", #selector(moveEarlier))
            add(menu, "Move Later", #selector(moveLater))
            add(menu, "Add Separator Before", #selector(separatorBefore))
            add(menu, "Add Separator After", #selector(separatorAfter))
        }
        add(menu, "Show in Finder", #selector(reveal))
        if app.isRunning && app.bundleIdentifier != "com.apple.finder" {
            menu.addItem(.separator())
            add(menu, "Quit", #selector(quitApp))
        }
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self }
    @objc private func openApp() { model.launch(app, toggle: false, anchor: self) }
    private func readNativeMenu(path: [NativeMenuStep]) {
        menuGeneration += 1
        let generation = menuGeneration
        let url = app.url
        Task { @MainActor [weak self] in
            let result = await NativeDockMenu.read(for: url, path: path)
            guard let self, menuGeneration == generation, app.url == url, window?.isVisible == true else { return }
            switch result {
            case .failure(let failure): showFallbackMenu(message: failure.message)
            case .success(let entries): presentNativeMenu(entries, path: path, url: url)
            }
        }
    }
    private func presentNativeMenu(_ entries: [NativeMenuEntry], path: [NativeMenuStep], url: URL) {
        let menu = NSMenu(title: app.name)
        menu.autoenablesItems = false
        var commands: [DockMenuCommand] = []
        func command(_ title: String, enabled: Bool = true, marked: Bool = false, action: @escaping @MainActor () -> Void) {
            let handler = DockMenuCommand(action)
            commands.append(handler)
            let item = menu.addItem(withTitle: title, action: #selector(DockMenuCommand.invoke), keyEquivalent: "")
            item.target = handler
            item.isEnabled = enabled
            item.state = marked ? .on : .off
        }
        if !path.isEmpty {
            command("‹ Back") { [weak self] in self?.readNativeMenu(path: Array(path.dropLast())) }
            menu.addItem(.separator())
        }
        for entry in entries {
            if entry.title.isEmpty { menu.addItem(.separator()); continue }
            command(entry.title + (entry.submenu ? "…" : ""), enabled: entry.enabled, marked: entry.marked) { [weak self] in
                guard let self, app.url == url else { return }
                if entry.submenu { readNativeMenu(path: entry.path) }
                else {
                    Task { @MainActor [weak self] in
                        let failure = await NativeDockMenu.select(for: url, path: entry.path)
                        guard let self, app.url == url, window?.isVisible == true else { return }
                        if let failure { showFallbackMenu(message: failure.message) }
                    }
                }
            }
        }
        if !entries.isEmpty { menu.addItem(.separator()) }
        menu.addItem(.sectionHeader(title: "everyDock"))
        appendAppActions(to: menu)
        withExtendedLifetime(commands) { (superview as? DockSurface)?.presentMenu(menu, anchor: self) }
    }
    @objc private func showWindows() { (superview as? DockSurface)?.showWindows(self) }
    @objc private func closeWindows() { model.closeAllWindows(app) }
    @objc private func pin() { model.togglePin(app) }
    @objc private func separatorBefore() { model.addSeparator(beside: app, after: false) }
    @objc private func separatorAfter() { model.addSeparator(beside: app, after: true) }
    @objc private func moveEarlier() { model.movePin(app, offset: -1) }
    @objc private func moveLater() { model.movePin(app, offset: 1) }
    @objc private func reveal() { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
    @objc private func quitApp() { model.quit(app) }
}

@MainActor private final class DockMenuCommand: NSObject {
    private let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    @objc func invoke() {
        // Finish NSMenu tracking before opening another menu or contacting the system Dock.
        DispatchQueue.main.async { [action] in action() }
    }
}

@MainActor final class DockUtilityButton: DockIconButton {
    private let item: DockUtility
    private let model: AppModel
    init(item: DockUtility, model: AppModel) {
        self.item = item
        self.model = model
        super.init(frame: .zero)
        target = self
        action = #selector(activate)
        setArtwork(model.utilities.icon(item))
        toolTip = item.title
        setAccessibilityLabel(item.title)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func activate() {
        let edge: NSRectEdge = model.preferences.edge == .bottom ? .maxY : model.preferences.edge == .left ? .maxX : .minX
        model.utilities.activate(item, from: self, edge: edge)
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: item == .desktop ? "Open Desktop Folder" : "Open in Finder", action: #selector(openFolder), keyEquivalent: "").target = self
        if item == .trash {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Empty Trash…", action: #selector(emptyTrash), keyEquivalent: "").target = self
        }
        (superview as? DockSurface)?.presentMenu(menu, anchor: self)
    }
    @objc private func openFolder() { NSWorkspace.shared.open(item.url) }
    @objc private func emptyTrash() {
        model.utilities.emptyTrash { [weak model] error in
            if let error { model?.message = error; model?.showSettings?() }
        }
    }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { item == .trash ? .move : .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        model.utilities.drop(urls, onto: item) { [weak model] error in
            if let error { model?.message = error; model?.showSettings?() }
        }
        return true
    }
}
