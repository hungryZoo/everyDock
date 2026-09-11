import AppKit
import SwiftUI
import QuickLookThumbnailing
import DockCore

enum DockUtility: String, CaseIterable, Sendable {
    case desktop, downloads, trash
    var title: String {
        switch self { case .desktop: "바탕화면"; case .downloads: "다운로드"; case .trash: "휴지통" }
    }
    var url: URL {
        switch self {
        case .desktop: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        case .downloads: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .trash: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        }
    }
}

@MainActor final class DockUtilities {
    private var stack: NSPopover?
    private var stackContents: FolderContents?
    private var stackSession: UUID?
    private let downloads = FolderContents(folder: DockUtility.downloads.url, title: "다운로드", symbol: "arrow.down.circle")
    private let desktop = FolderContents(folder: DockUtility.desktop.url, title: "바탕화면", symbol: "desktopcomputer")
    private var trashWatcher: DispatchSourceFileSystemObject?
    private var icons: [DockUtility: NSImage] = [:]
    private var trashRefresh: Task<Void, Never>?
    private var trashDirty = false
    var onChange: (() -> Void)?

    init() {
        for item in [DockUtility.desktop, .downloads] { icons[item] = NSWorkspace.shared.icon(forFile: item.url.path) }
        refreshTrash()
        let descriptor = open(DockUtility.trash.url.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
            source.setEventHandler { [weak self] in Task { @MainActor in self?.refreshTrash() } }
            source.setCancelHandler { Darwin.close(descriptor) }
            source.resume()
            trashWatcher = source
        }
    }
    func stop() { trashRefresh?.cancel(); trashWatcher?.cancel(); stack?.performClose(nil) }

    func icon(_ item: DockUtility) -> NSImage {
        icons[item] ?? NSImage(named: "NSTrashEmpty") ?? NSImage(systemSymbolName: "trash", accessibilityDescription: "휴지통")!
    }

    private func refreshTrash() {
        trashDirty = true
        guard trashRefresh == nil else { return }
        trashRefresh = Task { @MainActor in
            while trashDirty && !Task.isCancelled {
                trashDirty = false
                let nonempty = await Task.detached(priority: .utility) {
                    (try? FileManager.default.contentsOfDirectory(atPath: DockUtility.trash.url.path).contains { $0 != ".DS_Store" }) ?? false
                }.value
                guard !Task.isCancelled else { break }
                icons[.trash] = NSImage(named: nonempty ? "NSTrashFull" : "NSTrashEmpty")
                onChange?()
            }
            trashRefresh = nil
        }
    }

    func activate(_ item: DockUtility, from anchor: NSView, edge: NSRectEdge) {
        switch item {
        case .desktop, .downloads:
            show(item == .desktop ? desktop : downloads, from: anchor, edge: edge)
        case .trash: NSWorkspace.shared.open(item.url)
        }
    }

    func showApplications(onError: @escaping @MainActor @Sendable (String) -> Void) {
        stack?.performClose(nil)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.apps.launcher")
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher") else {
            onError("macOS의 Apps 실행기를 찾지 못했습니다. Spotlight에서 ⌘1을 눌러 앱을 열어 주세요.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        // The system launcher sends the Apps request on launch. Re-activation alone may do nothing.
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            let detail = error?.localizedDescription
            if let detail { Task { @MainActor in onError("Apps를 열지 못했습니다: \(detail)") } }
        }
    }
    private func show(_ contents: FolderContents, from anchor: NSView, edge: NSRectEdge) {
        let toggleClosed = stack?.isShown == true && stackContents === contents
        if let stackSession { stackContents?.endPresentation(stackSession) }
        stack?.performClose(nil)
        stack = nil
        if toggleClosed { return }
        let session = contents.beginPresentation()
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.contentViewController = NSHostingController(rootView: FolderStack(contents: contents, session: session) { [weak popover] in popover?.performClose(nil) })
        stack = popover
        stackContents = contents
        stackSession = session
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
    }
    func drop(_ urls: [URL], onto item: DockUtility, completion: @escaping @MainActor @Sendable (String?) -> Void) {
        if item == .trash {
            NSWorkspace.shared.recycle(urls) { [weak self] _, error in
                let detail = error?.localizedDescription
                Task { @MainActor in completion(detail); self?.refreshTrash() }
            }
        } else {
            // Copy, never silently move or overwrite the user's original files.
            Task { @MainActor in
                let result = await Task.detached {
                    do {
                        for url in urls {
                            let target = item.url.appendingPathComponent(url.lastPathComponent)
                            guard url.standardizedFileURL != target.standardizedFileURL else { continue }
                            try FileManager.default.copyItem(at: url, to: target)
                        }
                        return Optional<String>.none
                    } catch { return error.localizedDescription }
                }.value
                completion(result)
            }
        }
    }

    func emptyTrash(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "휴지통을 비우겠습니까?"
        alert.informativeText = "현재 사용자 계정의 휴지통에 있는 항목이 영구적으로 삭제됩니다. 외장 드라이브의 휴지통은 포함하지 않습니다. 이 작업은 취소할 수 없습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "취소")
        alert.addButton(withTitle: "휴지통 비우기")
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        alert.window.initialFirstResponder = alert.buttons[0]
        NSApp.activate()
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        Task { @MainActor in
            let result = await Task.detached {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: DockUtility.trash.url, includingPropertiesForKeys: nil)
                    for file in files { try FileManager.default.removeItem(at: file) }
                    return Optional<String>.none
                } catch { return error.localizedDescription }
            }.value
            completion(result)
            refreshTrash()
        }
    }
}

struct StackFile: Identifiable, @unchecked Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let date: Date
    var icon: NSImage
    let isDirectory: Bool
}

private struct FolderStack: View {
    @ObservedObject var contents: FolderContents
    let session: UUID
    let close: () -> Void
    private var folder: URL { contents.folder }
    @State private var openError: String?
    private var files: [StackFile] { contents.files }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(contents.title, systemImage: contents.symbol).font(.headline)
                Spacer()
                Button("Finder에서 열기") { NSWorkspace.shared.open(folder); close() }
            }
            Text("수정일 최신순 · 최대 80개").font(.caption).foregroundStyle(.secondary)
            if let openError { Text(openError).foregroundStyle(.secondary) }
            if contents.loading {
                VStack(spacing: 12) {
                    ProgressView()
                    if contents.waitingForAccess {
                        Text("폴더 접근 응답을 기다리고 있습니다. macOS의 \(contents.title) 폴더 접근 요청을 확인해 주세요.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("폴더 접근 설정 열기…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
                        }
                    }
                }.frame(maxWidth: .infinity).padding(24)
            }
            else if let error = contents.error {
                Text(error).foregroundStyle(.secondary)
                Button("폴더 접근 허용…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.directoryURL = folder
                    panel.prompt = "허용"
                    if panel.runModal() == .OK { contents.load(for: session) }
                }
            } else if contents.files.isEmpty { Text("\(contents.title) 폴더가 비어 있습니다.").foregroundStyle(.secondary).padding(32) }
            else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
                        ForEach(files) { file in
                            Button {
                                if NSWorkspace.shared.open(file.url) { close() }
                                else { openError = "항목을 열지 못했습니다. Finder에서 위치를 확인해 주세요." }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(nsImage: file.icon).resizable().scaledToFit().frame(width: 48, height: 48)
                                    Text(file.name).font(.caption).lineLimit(2).multilineTextAlignment(.center).frame(height: 30)
                                }.frame(width: 82)
                            }.buttonStyle(.plain).help(file.name)
                        }
                    }.padding(.vertical, 4)
                }.frame(maxHeight: 380)
            }
        }.padding(18).frame(width: 400).onAppear { contents.load(for: session) }.onDisappear { contents.endPresentation(session) }
    }
}

// Keep one directory request per folder, including while a system permission prompt
// is pending. Opening/closing the popover must not accumulate blocked workers.
@MainActor final class FolderContents: ObservableObject {
    let folder: URL
    let title: String
    let symbol: String
    @Published var files: [StackFile] = []
    @Published var loading = true
    @Published var waitingForAccess = false
    @Published var error: String?
    private(set) var request: Task<Void, Never>?
    private var visible = false
    private(set) var presentation: UUID?
    private var thumbnailGeneration = 0
    private var thumbnails: [URL: QLThumbnailGenerator.Request] = [:]
    private var thumbnailTimeouts: [URL: Task<Void, Never>] = [:]
    private var queue: [StackFile] = []
    private var cache: [URL: (date: Date, image: NSImage)] = [:]
    private let readDirectory: @Sendable (URL) async -> Result<[StackFile], Error>
    init(folder: URL, title: String, symbol: String,
         readDirectory: @escaping @Sendable (URL) async -> Result<[StackFile], Error> = FolderContents.readFiles) {
        self.folder = folder; self.title = title; self.symbol = symbol
        self.readDirectory = readDirectory
    }
    func beginPresentation() -> UUID {
        cancelThumbnails()
        let token = UUID()
        presentation = token
        visible = true
        return token
    }
    func endPresentation(_ token: UUID) {
        guard presentation == token else { return }
        presentation = nil
        cancelThumbnails()
    }
    func load(for token: UUID) {
        guard presentation == token else { return }
        guard request == nil else { return }
        cancelThumbnails(); visible = true
        // Keep the last successful grid and its images visible while refreshing metadata.
        loading = files.isEmpty
        waitingForAccess = false
        request = Task { @MainActor in
            let waiting = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled && loading { waitingForAccess = true }
            }
            let result = await readDirectory(folder)
            waiting.cancel()
            switch result {
            case .success(var value):
                for index in value.indices {
                    if let hit = cache[value[index].url], hit.date == value[index].date { value[index].icon = hit.image }
                }
                files = value; error = nil
            case .failure(let failure):
                let code = failure as NSError
                error = code.domain == NSCocoaErrorDomain && code.code == NSFileReadNoPermissionError
                    ? "\(title) 폴더에 접근할 수 없습니다. 폴더 접근을 허용해 주세요."
                    : "\(title) 폴더를 읽지 못했습니다: \(failure.localizedDescription)"
            }
            loading = false
            waitingForAccess = false
            request = nil
            if visible && error == nil { startThumbnails() }
        }
    }
    nonisolated static func readFiles(_ folder: URL) async -> Result<[StackFile], Error> {
        await Task.detached {
            Result {
                let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles])
                let ordered = urls.map { url in (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
                    .sorted { FileOrdering.precedes(date: $0.1, name: $0.0.lastPathComponent, otherDate: $1.1, otherName: $1.0.lastPathComponent) }
                return ordered.prefix(80).map { url, date in
                    StackFile(url: url, name: FileManager.default.displayName(atPath: url.path), date: date,
                              icon: NSWorkspace.shared.icon(forFile: url.path),
                              isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
                }

            }
        }.value
    }
    func cancelThumbnails() {
        visible = false; thumbnailGeneration += 1
        thumbnails.values.forEach { QLThumbnailGenerator.shared.cancel($0) }
        thumbnailTimeouts.values.forEach { $0.cancel() }
        thumbnailTimeouts.removeAll()
        thumbnails.removeAll(); queue.removeAll()
    }
    private func startThumbnails() {
        let current = Set(files.map(\.url))
        cache = cache.filter { current.contains($0.key) }
        queue = files.filter { !$0.isDirectory && cache[$0.url]?.date != $0.date }
        pumpThumbnails()
    }
    private func pumpThumbnails() {
        while visible && thumbnails.count < 3 && !queue.isEmpty {
            let file = queue.removeFirst(), generation = thumbnailGeneration
            let request = QLThumbnailGenerator.Request(fileAt: file.url, size: CGSize(width: 48, height: 48), scale: 2, representationTypes: .thumbnail)
            thumbnails[file.url] = request
            thumbnailTimeouts[file.url] = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled, let self, generation == thumbnailGeneration,
                      thumbnails[file.url] === request else { return }
                QLThumbnailGenerator.shared.cancel(request)
                thumbnails[file.url] = nil
                thumbnailTimeouts[file.url] = nil
                pumpThumbnails()
            }
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
                let pixels = representation?.cgImage
                Task { @MainActor in
                    guard let self, self.visible, generation == self.thumbnailGeneration,
                          self.thumbnails[file.url] != nil else { return }
                    self.thumbnailTimeouts.removeValue(forKey: file.url)?.cancel()
                    self.thumbnails[file.url] = nil
                    if let pixels, let index = self.files.firstIndex(where: { $0.url == file.url && $0.date == file.date }) {
                        let image = NSImage(cgImage: pixels, size: .zero)
                        self.cache[file.url] = (file.date, image); self.files[index].icon = image
                    }
                    self.pumpThumbnails()
                }
            }
        }
    }
}
