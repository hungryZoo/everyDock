import AppKit
import Combine
import DockCore
import QuartzCore

@MainActor final class DockSurface: NSView {
    private let model: AppModel
    private let glass = NSGlassEffectView()
    private let indicators = DockIndicators()
    private let tooltip = NSTextField(labelWithString: "")
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
        tooltip.alignment = .center
        tooltip.font = .systemFont(ofSize: 13, weight: .medium)
        tooltip.textColor = .labelColor
        tooltip.drawsBackground = true
        tooltip.backgroundColor = .windowBackgroundColor.withAlphaComponent(0.95)
        tooltip.wantsLayer = true
        tooltip.layer?.cornerRadius = 7
        tooltip.layer?.masksToBounds = true
        tooltip.isHidden = true
        tooltip.setAccessibilityElement(false)
        addSubview(tooltip)
        menuButton.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "everyDock 메뉴")
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(showDockMenu)
        menuButton.toolTip = "everyDock 메뉴"
        menuButton.setAccessibilityLabel("everyDock 메뉴")
        // Dock controls live in the menu bar and the Dock background's contextual menu.
        for item in DockUtility.allCases {
            let button = DockUtilityButton(item: item, model: model)
            utilityButtons[item] = button
            addSubview(button, positioned: .below, relativeTo: tooltip)
        }
        registerForDraggedTypes([.fileURL])
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
        edge = model.preferences.edge
        magnification = model.magnification
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !model.preferences.showPreviews { previews.close() }
        for (item, button) in utilityButtons {
            button.setArtwork(model.utilities.icon(item))
            if item == .desktop {
                let title = model.utilities.isDesktopShowing ? "창 다시 보기" : item.title
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
            button.setArtwork(app.icon)
            button.setAccessibilityValue(app.isLaunching ? "실행 중…" : app.isHidden ? "숨겨짐" : app.isActive ? "활성 앱" : app.isRunning ? "실행 중" : "실행되지 않음")
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
        let usable = max(20, length - DockMetrics.padding * 2 - DockMetrics.separatorSpace - reserve)
        baseSize = min(model.iconSize, max(20, (usable + DockMetrics.gap) / Double(max(1, model.apps.count + 3)) - DockMetrics.gap))
        let capacity = max(1, Int((usable + DockMetrics.gap + 0.1) / (baseSize + DockMetrics.gap)) - 3)
        scrollIndex = min(scrollIndex, max(0, model.apps.count - capacity))
        visibleApps = Array(model.apps.dropFirst(scrollIndex).prefix(capacity))
        itemIDs = visibleApps.map(\.id) + DockUtility.allCases.map { "utility.\($0.rawValue)" }
        let visibleIDs = Set(visibleApps.map(\.id))
        buttons.forEach { $0.value.isHidden = !visibleIDs.contains($0.key) }
        menuButton.toolTip = model.apps.count > capacity ? "everyDock 메뉴 · 스크롤로 나머지 앱 표시" : "everyDock 메뉴"
    }

    func updatePointer(at location: NSPoint? = nil) {
        guard let window, window.isVisible, !model.paused else { hoverPoint = nil; return }
        let point = convert(window.convertPoint(fromScreen: location ?? NSEvent.mouseLocation), from: nil)
        let onDock = backgroundRect.contains(point) || buttons.values.contains { !$0.isHidden && $0.frame.contains(point) }
            || utilityButtons.values.contains { $0.frame.contains(point) }
        let hovered = visibleApps.first { buttons[$0.id]?.frame.contains(point) == true }
        previews.update(app: onDock ? hovered : nil, anchor: hovered.flatMap { buttons[$0.id] }, screenPoint: location ?? NSEvent.mouseLocation)
        if debugPointer, point != lastDiagnosticPoint {
            lastDiagnosticPoint = point
            let line = "pointer screen=\(NSEvent.mouseLocation) window=\(window.frame) local=\(point) bar=\(backgroundRect) hit=\(onDock)\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
        // Transparent animation space passes clicks through to the user's other windows.
        if window.ignoresMouseEvents == onDock { window.ignoresMouseEvents = !onDock }
        let next = onDock ? point : nil
        if next != hoverPoint { hoverPoint = next; animate() }
    }

    private func animate() {
        guard displayLink == nil, window != nil else { return }
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
        let baselineLength = DockMetrics.length(iconSize: baseSize, appCount: visibleApps.count)
        let baselineStart = (length - baselineLength) / 2 + DockMetrics.padding
        let pointerAxis = hoverPoint.map { horizontal ? $0.x : bounds.height - $0.y }
        var needsAnotherFrame = false
        var sizes: [Double] = []
        for (index, id) in allIDs.enumerated() {
            let center = baselineStart + Double(index) * (baseSize + DockMetrics.gap) + baseSize / 2 + (index >= visibleApps.count ? DockMetrics.separatorSpace : 0)
            let target = pointerAxis.map { DockMotion.scale(distance: $0 - center, iconSize: baseSize,
                                                           magnification: magnification) } ?? 1
            let previous = scales[id] ?? 1
            let scale = abs(target - previous) < 0.001 ? target : previous + (target - previous) * interpolation
            scales[id] = scale
            needsAnotherFrame = needsAnotherFrame || abs(target - scale) > 0.001
            sizes.append(baseSize * scale)
        }
        let total = sizes.reduce(0, +) + Double(max(0, sizes.count - 1)) * DockMetrics.gap + DockMetrics.padding * 2 + DockMetrics.separatorSpace
        var cursor = (length - total) / 2 + DockMetrics.padding
        let thickness = DockMetrics.thickness(iconSize: baseSize)
        backgroundRect = orientedRect(axis: (length - total) / 2, inward: 0, length: total, thickness: thickness)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if glass.frame != backgroundRect { glass.frame = backgroundRect }
        if glass.cornerRadius != thickness * 0.28 { glass.cornerRadius = thickness * 0.28 }
        if indicators.frame != bounds { indicators.frame = bounds }
        indicators.dots.removeAll(keepingCapacity: true)
        for (index, app) in visibleApps.enumerated() {
            let size = sizes[index]
            var bounce = 0.0
            if !reduceMotion, let start = launches[app.id] {
                bounce = DockMotion.bounce(elapsed: now - start, iconSize: baseSize)
                needsAnotherFrame = true
            } else if !reduceMotion, let start = clicks[app.id], now - start < 0.3 {
                bounce = sin((now - start) / 0.3 * .pi) * 5
                needsAnotherFrame = true
            } else { clicks.removeValue(forKey: app.id) }
            buttons[app.id]?.frame = orientedRect(axis: cursor, inward: DockMetrics.iconBaseline + bounce, length: size, thickness: size)
            if app.isRunning || app.isLaunching {
                indicators.dots.append((orientedRect(axis: cursor + size / 2 - 1.5, inward: 3, length: 3, thickness: 3), app.isActive))
            }
            cursor += size + DockMetrics.gap
        }
        indicators.separator = orientedRect(axis: cursor + DockMetrics.separatorSpace / 2, inward: 10, length: 0.5, thickness: max(10, thickness - 20))
        cursor += DockMetrics.separatorSpace
        for (index, item) in DockUtility.allCases.enumerated() {
            let size = sizes[visibleApps.count + index]
            utilityButtons[item]?.frame = orientedRect(axis: cursor, inward: DockMetrics.iconBaseline, length: size, thickness: size)
            cursor += size + DockMetrics.gap
        }
        indicators.apply()
        let hovered = hoverPoint.flatMap { point in visibleApps.first { buttons[$0.id]?.frame.contains(point) == true } }
        if let hovered, let button = buttons[hovered.id] {
            let title = hovered.name + (hovered.isLaunching ? " — 실행 중…" : "")
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
        previews.close()
        clicks[sender.app.id] = ProcessInfo.processInfo.systemUptime
        model.launch(sender.app)
        animate()
    }
    override func scrollWheel(with event: NSEvent) {
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        guard abs(delta) > 0.1 else { return }
        scrollIndex = max(0, scrollIndex + (delta < 0 ? 1 : -1))
        updateVisibleApps()
        animate()
    }
    @objc private func showDockMenu() {
        let menu = NSMenu()
        add(menu, "앱 추가…", #selector(addApps))
        add(menu, "설정…", #selector(settings))
        menu.addItem(.separator())
        add(menu, "모든 Dock 일시 숨기기", #selector(pause))
        add(menu, "everyDock 종료", #selector(quit))
        let point = convert(window?.convertPoint(fromScreen: NSEvent.mouseLocation) ?? .zero, from: nil)
        menu.popUp(positioning: nil, at: point, in: self)
    }
    override func rightMouseDown(with event: NSEvent) { showDockMenu() }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self }
    @objc private func addApps() { model.chooseApps() }
    @objc private func settings() { model.showSettings?() }
    @objc private func pause() { model.paused = true }
    @objc private func quit() { NSApp.terminate(nil) }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let apps = urls.filter { $0.pathExtension.lowercased() == "app" }
        model.addApps(apps)
        return !apps.isEmpty
    }
}

private final class DockIndicators: NSView {
    var dots: [(NSRect, Bool)] = []
    var separator = NSRect.zero
    private var dotLayers: [CALayer] = []
    private let separatorLayer = CALayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(separatorLayer)
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
        separatorLayer.frame = separator
        separatorLayer.backgroundColor = NSColor.separatorColor.cgColor
    }
}

/// Rasterize artwork once; changing an icon's bounds only changes its composited layer.
@MainActor class DockIconButton: NSButton {
    private var artwork: NSImage?
    private var pixels: CGImage?
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        title = ""
        imagePosition = .imageOnly
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .resizeAspect
        isBordered = false
        setButtonType(.momentaryChange)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.contents = pixels }
    func setArtwork(_ image: NSImage) {
        guard artwork !== image else { return }
        artwork = image
        var proposed = NSRect(x: 0, y: 0, width: 512, height: 512)
        pixels = image.cgImage(forProposedRect: &proposed, context: nil, hints: [.interpolation: NSImageInterpolation.high])
        layer?.contents = pixels
    }
    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.opacity = flag ? 0.6 : 1
        CATransaction.commit()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor final class DockAppButton: DockIconButton {
    var app: DockApplication
    private let model: AppModel
    init(app: DockApplication, model: AppModel) {
        self.app = app
        self.model = model
        super.init(frame: .zero)
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyUpOrDown
        setButtonType(.momentaryChange)
        wantsLayer = true
        setAccessibilityLabel(app.name)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu(title: app.name)
        add(menu, "열기", #selector(openApp))
        add(menu, app.isPinned ? "Dock에서 고정 해제" : "Dock에 고정", #selector(pin))
        if app.isPinned {
            add(menu, "앞으로 이동", #selector(moveEarlier))
            add(menu, "뒤로 이동", #selector(moveLater))
        }
        add(menu, "Finder에서 보기", #selector(reveal))
        if app.isRunning && app.bundleIdentifier != "com.apple.finder" {
            menu.addItem(.separator())
            add(menu, "종료", #selector(quitApp))
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self }
    @objc private func openApp() { model.launch(app, toggle: false) }
    @objc private func pin() { model.togglePin(app) }
    @objc private func moveEarlier() { model.movePin(app, offset: -1) }
    @objc private func moveLater() { model.movePin(app, offset: 1) }
    @objc private func reveal() { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
    @objc private func quitApp() { model.quit(app) }
}

@MainActor final class DockUtilityButton: DockIconButton {
    private let item: DockUtility
    private let model: AppModel
    init(item: DockUtility, model: AppModel) {
        self.item = item
        self.model = model
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
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
        menu.addItem(withTitle: item == .desktop ? "바탕화면 폴더 열기" : "Finder에서 열기", action: #selector(openFolder), keyEquivalent: "").target = self
        if item == .trash {
            menu.addItem(.separator())
            menu.addItem(withTitle: "휴지통 비우기…", action: #selector(emptyTrash), keyEquivalent: "").target = self
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
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
