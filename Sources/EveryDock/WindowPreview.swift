import AppKit
import SwiftUI
@preconcurrency import ScreenCaptureKit

struct WindowPreview: Identifiable {
    let id: String
    let title: String
    let frame: CGRect
    let image: NSImage?
    let minimized: Bool
}

@MainActor final class WindowPreviewService {
    private var cache: [CGWindowID: (NSImage, Date)] = [:]
    func previews(for app: DockApplication) async -> [WindowPreview] {
        guard let process = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == app.url }) else { return [] }
        let descriptions = await WindowActions.list(pid: process.processIdentifier)
        guard CGPreflightScreenCaptureAccess() else {
            return descriptions.enumerated().map { WindowPreview(id: "ax-\($0.offset)", title: $0.element.title,
                                                                  frame: $0.element.frame, image: nil, minimized: $0.element.minimized) }
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let windows = content.windows.filter {
                $0.owningApplication?.processID == process.processIdentifier && $0.windowLayer == 0 && $0.frame.width > 80 && $0.frame.height > 60
            }.sorted { a, b in a.isOnScreen != b.isOnScreen ? a.isOnScreen : a.windowID < b.windowID }
            cache = cache.filter { Date().timeIntervalSince($0.value.1) < 60 }
            var results: [WindowPreview] = []
            for window in windows.prefix(8) {
                try Task.checkCancellation()
                var image = cache[window.windowID]?.0
                if window.isOnScreen || image == nil {
                    let config = SCStreamConfiguration()
                    let scale = min(440 / window.frame.width, 330 / window.frame.height)
                    config.width = max(1, Int(window.frame.width * scale))
                    config.height = max(1, Int(window.frame.height * scale))
                    config.showsCursor = false
                    config.ignoreShadowsSingleWindow = true
                    if let snapshot = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config) {
                        image = NSImage(cgImage: snapshot, size: NSSize(width: window.frame.width, height: window.frame.height))
                        cache[window.windowID] = (image!, Date())
                    }
                }
                let name = window.title ?? ""
                results.append(WindowPreview(id: String(window.windowID), title: name, frame: window.frame, image: image,
                                             minimized: descriptions.contains { $0.title == name && $0.minimized }))
            }
            if cache.count > 32 { cache = Dictionary(uniqueKeysWithValues: cache.sorted { $0.value.1 > $1.value.1 }.prefix(32).map { ($0.key, $0.value) }) }
            for (index, description) in descriptions.enumerated() where !results.contains(where: { $0.title == description.title }) {
                results.append(WindowPreview(id: "ax-\(index)", title: description.title, frame: description.frame, image: nil, minimized: description.minimized))
            }
            return results
        } catch {
            return descriptions.enumerated().map { WindowPreview(id: "ax-\($0.offset)", title: $0.element.title,
                                                                  frame: $0.element.frame, image: nil, minimized: $0.element.minimized) }
        }
    }
}

@MainActor final class WindowPreviewController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let service = WindowPreviewService()
    private let popover = NSPopover()
    private var pending: Task<Void, Never>?
    private var refresh: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var targetID: String?
    private weak var anchor: NSView?
    var onVisibilityChange: ((Bool) -> Void)?
    init(model: AppModel) {
        self.model = model
        super.init()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
    }
    var isShown: Bool { popover.isShown }
    func update(app: DockApplication?, anchor: NSView?, screenPoint: NSPoint) {
        let overPreview = popover.contentViewController?.view.window?.frame.insetBy(dx: -8, dy: -8).contains(screenPoint) == true
        if overPreview { closeTask?.cancel(); closeTask = nil; return }
        guard model.preferences.showPreviews, let app, app.isRunning, let anchor else {
            pending?.cancel()
            guard targetID != nil || popover.isShown else { return }
            if closeTask == nil {
                closeTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(260))
                    guard !Task.isCancelled else { return }
                    close()
                }
            }
            return
        }
        closeTask?.cancel(); closeTask = nil
        guard targetID != app.id else { return }
        close()
        targetID = app.id
        self.anchor = anchor
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(model.preferences.previewDelay))
            guard !Task.isCancelled, targetID == app.id, anchor.window != nil else { return }
            let previews = await service.previews(for: app)
            guard !Task.isCancelled, targetID == app.id else { return }
            show(app: app, previews: previews, anchor: anchor)
            refresh = Task { @MainActor in
                while !Task.isCancelled && popover.isShown {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled, popover.isShown else { return }
                    let next = await service.previews(for: app)
                    guard !Task.isCancelled, popover.isShown else { return }
                    setContent(app: app, previews: next)
                }
            }
        }
    }
    private func setContent(app: DockApplication, previews: [WindowPreview]) {
        let content = PreviewContent(app: app, previews: previews, model: model) { [weak self] item in
            self?.close()
            guard let process = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == app.url }) else { return }
            Task { @MainActor in
                let raised = await WindowActions.focus(pid: process.processIdentifier, title: item.title, bounds: item.frame)
                process.unhide()
                process.activate(options: [])
                if !raised { self?.model.launch(app, toggle: false) }
            }
        }
        if let host = popover.contentViewController as? NSHostingController<PreviewContent> {
            host.rootView = content
        } else { popover.contentViewController = NSHostingController(rootView: content) }
    }
    private func show(app: DockApplication, previews: [WindowPreview], anchor: NSView) {
        setContent(app: app, previews: previews)
        let edge: NSRectEdge = model.preferences.edge == .bottom ? .maxY : model.preferences.edge == .left ? .maxX : .minX
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
        onVisibilityChange?(true)
    }
    func close() {
        pending?.cancel(); pending = nil
        refresh?.cancel(); refresh = nil
        closeTask?.cancel(); closeTask = nil
        targetID = nil
        anchor = nil
        popover.performClose(nil)
        onVisibilityChange?(false)
    }
    func popoverDidClose(_ notification: Notification) {
        refresh?.cancel()
        onVisibilityChange?(false)
    }
}

private struct PreviewContent: View {
    let app: DockApplication
    let previews: [WindowPreview]
    @ObservedObject var model: AppModel
    let select: (WindowPreview) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                Text(app.name).font(.headline)
                Spacer()
                Text("\(previews.count)개 창").font(.caption).foregroundStyle(.secondary)
            }
            if !model.screenCaptureEnabled {
                Button("창 미리보기를 위해 화면 기록 허용…", action: model.requestScreenCapture)
                    .buttonStyle(.bordered)
            }
            if previews.isEmpty {
                Text(model.screenCaptureEnabled ? "표시할 창이 없습니다." : "권한을 허용하면 이 앱의 창을 미리 볼 수 있습니다.")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(previews) { preview in
                            Button { select(preview) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Group {
                                        if let image = preview.image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
                                        else { Image(systemName: preview.minimized ? "minus.rectangle" : "macwindow").font(.largeTitle).foregroundStyle(.secondary) }
                                    }
                                    .frame(width: 190, height: 118)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                    Text(preview.title.isEmpty ? app.name : preview.title).font(.caption).lineLimit(1)
                                    if preview.minimized { Text("최소화됨").font(.caption2).foregroundStyle(.secondary) }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(height: min(340, CGFloat((previews.count + 1) / 2) * 160))
            }
        }.padding(16).frame(width: 420)
    }
}
