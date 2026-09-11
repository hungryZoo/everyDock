import AppKit
import SwiftUI
import DockCore
@preconcurrency import ScreenCaptureKit

struct WindowPreview: Identifiable {
    var id: WindowReference { window.reference }
    let window: WindowDescription
    let image: NSImage?
    var title: String { window.title }
    var minimized: Bool { window.minimized }
}
struct PreviewResult {
    let windows: [WindowPreview]
    let message: String?
}

@MainActor final class WindowPreviewService {
    private var cache: [WindowReference: (NSImage, Date)] = [:]
    private let permissions: AppPermissions
    init(permissions: AppPermissions) { self.permissions = permissions }
    func previews(for app: DockApplication) async -> PreviewResult {
        guard let process = NSWorkspace.shared.runningApplications.first(where: { !$0.isTerminated && ($0.bundleURL == app.url || (app.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)) }) else {
            return PreviewResult(windows: [], message: "앱이 종료되었습니다.")
        }
        let list = await WindowActions.list(pid: process.processIdentifier)
        permissions.recordAccessibility(list.failure)
        if let failure = list.failure {
            return PreviewResult(windows: [], message: failure == .permissionDenied
                                 ? "창 목록을 읽으려면 손쉬운 사용 접근을 허용해 주세요."
                                 : "앱의 창 목록을 읽지 못했습니다. 잠시 후 다시 시도해 주세요.")
        }
        guard !list.windows.isEmpty else { return PreviewResult(windows: [], message: nil) }
        cache = cache.filter { Date().timeIntervalSince($0.value.1) < 60 }
        do {
            let content = try await permissions.shareableContent()
            let captures = content.windows.filter {
                $0.owningApplication?.processID == process.processIdentifier && $0.windowLayer == 0 && $0.frame.width > 0 && $0.frame.height > 0
            }.sorted { a, b in a.isOnScreen != b.isOnScreen ? a.isOnScreen : a.windowID < b.windowID }
            let pairs = WindowMatching.match(windows: list.windows.map { .init(title: $0.title, frame: $0.frame) },
                                             captures: captures.map { .init(title: $0.title ?? "", frame: $0.frame) })
            var results: [WindowPreview] = []
            var captureError: String?
            for (index, description) in list.windows.enumerated() {
                try Task.checkCancellation()
                var image = cache[description.reference]?.0
                if index < 8, let match = pairs[index] {
                    let window = captures[match]
                    if window.isOnScreen || image == nil {
                        let config = SCStreamConfiguration()
                        let scale = min(440 / window.frame.width, 330 / window.frame.height)
                        config.width = max(1, Int(window.frame.width * scale))
                        config.height = max(1, Int(window.frame.height * scale))
                        config.showsCursor = false
                        config.ignoreShadowsSingleWindow = true
                        do {
                            guard permissions.canCaptureWithoutPrompt else { throw CaptureFailure.permissionRequired }
                            let snapshot = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
                            image = NSImage(cgImage: snapshot, size: window.frame.size)
                            cache[description.reference] = (image!, Date())
                        } catch {
                            permissions.recordCaptureError(error)
                            captureError = "일부 창 이미지를 가져오지 못했습니다. 제목을 눌러 창을 열 수 있습니다."
                        }
                    }
                }
                results.append(WindowPreview(window: description, image: image))
            }
            if cache.count > 32 { cache = Dictionary(uniqueKeysWithValues: cache.sorted { $0.value.1 > $1.value.1 }.prefix(32).map { ($0.key, $0.value) }) }
            return PreviewResult(windows: results, message: captureError)
        } catch {
            let message: String?
            if let failure = error as? CaptureFailure, case .permissionDenied = failure { message = "macOS가 현재 앱의 화면 접근을 거부했습니다. 제목으로 창을 선택하거나 닫을 수 있습니다." }
            else if let failure = error as? CaptureFailure, case .permissionRequired = failure { message = "창 이미지를 보려면 화면 녹화 권한 확인 버튼을 눌러 주세요. 제목으로 창을 선택하거나 닫을 수 있습니다." }
            else if error is CancellationError { message = nil }
            else { message = "창 이미지를 가져오지 못했습니다: \(error.localizedDescription)" }
            return PreviewResult(windows: list.windows.map { WindowPreview(window: $0, image: nil) }, message: message)
        }
    }
}

@MainActor final class WindowPreviewController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let service: WindowPreviewService
    private let popover = NSPopover()
    private var pending: Task<Void, Never>?
    private var refresh: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var targetID: String?
    private var manual = false
    private var closingWindow = false
    private weak var anchor: NSView?
    var onVisibilityChange: ((Bool) -> Void)?
    init(model: AppModel) {
        self.model = model
        service = WindowPreviewService(permissions: model.permissions)
        super.init()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
    }
    var isShown: Bool { popover.isShown }
    func update(app: DockApplication?, anchor: NSView?, screenPoint: NSPoint) {
        guard !manual, !closingWindow else { return }
        let overPreview = popover.isShown && popover.contentViewController?.view.window?.frame.insetBy(dx: -8, dy: -8).contains(screenPoint) == true
        if overPreview { closeTask?.cancel(); closeTask = nil; return }
        guard model.preferences.showPreviews, let app, app.isRunning, let anchor else {
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
        start(app: app, anchor: anchor, manual: false)
    }
    func showImmediately(app: DockApplication, anchor: NSView) { start(app: app, anchor: anchor, manual: true) }
    private func start(app: DockApplication, anchor: NSView, manual: Bool) {
        close()
        self.manual = manual
        targetID = app.id
        self.anchor = anchor
        pending = Task { @MainActor in
            if !manual { try? await Task.sleep(for: .seconds(model.preferences.previewDelay)) }
            guard !Task.isCancelled, targetID == app.id, anchor.window != nil else { return }
            let result = await service.previews(for: app)
            guard !Task.isCancelled, targetID == app.id else { return }
            setContent(app: app, previews: result)
            let edge: NSRectEdge = model.preferences.edge == .bottom ? .maxY : model.preferences.edge == .left ? .maxX : .minX
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
            onVisibilityChange?(true)
            refresh = Task { @MainActor in
                while !Task.isCancelled && popover.isShown {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled, popover.isShown else { return }
                    if closingWindow { continue }
                    let next = await service.previews(for: app)
                    guard !Task.isCancelled, popover.isShown, !closingWindow else { continue }
                    setContent(app: app, previews: next)
                }
            }
        }
    }
    private func setContent(app: DockApplication, previews: PreviewResult) {
        let content = PreviewContent(app: app, previews: previews.windows, status: previews.message, model: model, select: { [weak self] item in
            self?.close()
            Task { @MainActor in
                let failure = await WindowActions.focus(item.id)
                self?.model.permissions.recordAccessibility(failure)
                let process = NSRunningApplication(processIdentifier: item.id.pid)
                process?.unhide()
                process?.activate(options: [])
                if failure != nil { self?.model.launch(app, toggle: false) }
            }
        }, closeWindow: { [weak self] item in
            guard let self, !closingWindow else { return nil }
            closingWindow = true
            closeTask?.cancel(); closeTask = nil
            defer { closingWindow = false }
            let result = await WindowActions.close(item.id)
            if case .failed(let failure) = result { model.permissions.recordAccessibility(failure) }
            else { model.permissions.recordAccessibility(nil) }
            if case .awaitingApplication = result {
                let process = NSRunningApplication(processIdentifier: item.id.pid)
                process?.unhide()
                process?.activate(options: [])
                close()
                return result.message
            }
            model.permissions.invalidateContent()
            let next = await service.previews(for: app)
            if popover.isShown, targetID == app.id { setContent(app: app, previews: next) }
            return result.message
        })
        if let host = popover.contentViewController as? NSHostingController<PreviewContent> { host.rootView = content }
        else { popover.contentViewController = NSHostingController(rootView: content) }
        if let view = popover.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            popover.contentSize = view.fittingSize
        }
    }
    func close() {
        clearTasks()
        popover.performClose(nil)
        onVisibilityChange?(false)
    }
    private func clearTasks() {
        pending?.cancel(); pending = nil
        refresh?.cancel(); refresh = nil
        closeTask?.cancel(); closeTask = nil
        targetID = nil; anchor = nil; manual = false
    }
    func popoverDidClose(_ notification: Notification) { clearTasks(); onVisibilityChange?(false) }
}

private struct PreviewContent: View {
    let app: DockApplication
    let previews: [WindowPreview]
    let status: String?
    @ObservedObject var model: AppModel
    let select: (WindowPreview) -> Void
    let closeWindow: (WindowPreview) async -> String?
    @State private var busy = false
    @State private var closeMessage: String?
    private var layout: DockCore.PreviewLayout { DockCore.PreviewLayout(count: previews.count) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                Text(app.name).font(.headline)
                Spacer()
                Text("\(previews.count)개 창").font(.caption).foregroundStyle(.secondary)
            }
            if !model.accessibilityEnabled { Button("손쉬운 사용 접근 확인…", action: model.requestAccessibility).buttonStyle(.bordered) }
            if !model.screenCaptureEnabled { Button("화면 접근 다시 확인…", action: model.requestScreenCapture).buttonStyle(.bordered) }
            if let status = closeMessage ?? status { Text(status).font(.callout).foregroundStyle(.secondary) }
            if previews.isEmpty {
                Text("표시할 창이 없습니다.").font(.callout).foregroundStyle(.secondary)
                Button("\(app.name) 열기") { model.launch(app, toggle: false) }.buttonStyle(.bordered).padding(.bottom, 8)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(190)), count: layout.columns), spacing: 12) {
                        ForEach(previews) { preview in
                            ZStack(alignment: .topLeading) {
                                Button { select(preview) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Group {
                                            if let image = preview.image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
                                            else { Image(systemName: preview.minimized ? "minus.rectangle" : "macwindow").font(.largeTitle).foregroundStyle(.secondary) }
                                        }
                                        .frame(width: 190, height: 118)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                        Text(preview.title.isEmpty ? app.name : preview.title).font(.caption).lineLimit(1)
                                        Text(preview.minimized ? "최소화됨" : " ").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }.buttonStyle(.plain).disabled(busy)
                                    .help(preview.title.isEmpty ? app.name : preview.title)
                                Button {
                                    busy = true
                                    Task { closeMessage = await closeWindow(preview); busy = false }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                        .frame(width: 24, height: 24).background(.regularMaterial, in: Circle())
                                }.buttonStyle(.plain).padding(5).disabled(busy || !preview.window.canClose)
                                    .accessibilityLabel("\(preview.title.isEmpty ? app.name : preview.title) 창 닫기")
                                    .help(preview.window.canClose ? "이 창 닫기" : "이 창은 닫기를 지원하지 않습니다")
                            }
                        }
                    }
                }.frame(height: layout.gridHeight)
                if previews.count > 8 { Text("이미지는 최대 8개 창에 표시됩니다. 모든 창을 선택하고 닫을 수 있습니다.").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(16).frame(width: layout.width)
    }
}
