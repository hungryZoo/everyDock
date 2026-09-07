import AppKit
import SwiftUI

enum DockUtility: String, CaseIterable, Sendable {
    case desktop, downloads, trash
    var title: String {
        switch self { case .desktop: "바탕화면 보기"; case .downloads: "다운로드"; case .trash: "휴지통" }
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
    private var hidden: [NSRunningApplication] = []
    private var previous: NSRunningApplication?
    private var stack: NSPopover?
    private let downloads = FolderContents(folder: DockUtility.downloads.url)
    private var trashWatcher: DispatchSourceFileSystemObject?
    var onChange: (() -> Void)?
    var isDesktopShowing: Bool { !hidden.isEmpty }

    init() {
        let descriptor = open(DockUtility.trash.url.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
            source.setEventHandler { [weak self] in Task { @MainActor in self?.onChange?() } }
            source.setCancelHandler { Darwin.close(descriptor) }
            source.resume()
            trashWatcher = source
        }
    }
    func stop() { restoreDesktop(); trashWatcher?.cancel(); stack?.performClose(nil) }

    func icon(_ item: DockUtility) -> NSImage {
        if item == .trash {
            let nonempty = (try? FileManager.default.contentsOfDirectory(atPath: item.url.path).contains { $0 != ".DS_Store" }) ?? false
            return NSImage(named: NSImage.Name(nonempty ? "NSTrashFull" : "NSTrashEmpty"))
                ?? NSImage(systemSymbolName: nonempty ? "trash.fill" : "trash", accessibilityDescription: "휴지통")!
        }
        return NSWorkspace.shared.icon(forFile: item.url.path)
    }

    func activate(_ item: DockUtility, from anchor: NSView, edge: NSRectEdge) {
        switch item {
        case .desktop: toggleDesktop()
        case .downloads:
            stack?.performClose(nil)
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: FolderStack(contents: downloads) { [weak popover] in popover?.performClose(nil) })
            stack = popover
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
        case .trash: NSWorkspace.shared.open(item.url)
        }
    }

    func toggleDesktop() {
        if hidden.isEmpty {
            previous = NSWorkspace.shared.frontmostApplication
            // Snapshot before issuing any request: hiding a frontmost app can activate
            // another app, and the immediate return value is not the resulting state.
            hidden = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isHidden }
            hidden.forEach { _ = $0.hide() }
        } else { restoreDesktop() }
        onChange?()
    }
    func restoreDesktop() {
        for process in hidden.reversed() where !process.isTerminated {
            process.unhide()
            process.activate(options: [.activateAllWindows])
        }
        hidden.removeAll()
        previous?.activate(options: [])
        previous = nil
        onChange?()
    }
    func drop(_ urls: [URL], onto item: DockUtility, completion: @escaping @MainActor @Sendable (String?) -> Void) {
        if item == .trash {
            NSWorkspace.shared.recycle(urls) { [weak self] _, error in
                let detail = error?.localizedDescription
                Task { @MainActor in completion(detail); self?.onChange?() }
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
            onChange?()
        }
    }
}

private struct StackFile: Identifiable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let date: Date
}

private struct FolderStack: View {
    @ObservedObject var contents: FolderContents
    let close: () -> Void
    private var folder: URL { contents.folder }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("다운로드", systemImage: "arrow.down.circle").font(.headline)
                Spacer()
                Button("Finder에서 열기") { NSWorkspace.shared.open(folder); close() }
            }
            if contents.loading {
                VStack(spacing: 12) {
                    ProgressView()
                    if contents.waitingForAccess {
                        Text("폴더 접근 응답을 기다리고 있습니다. macOS의 다운로드 폴더 접근 요청을 확인해 주세요.")
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
                    if panel.runModal() == .OK { contents.load() }
                }
            } else if contents.files.isEmpty { Text("다운로드 폴더가 비어 있습니다.").foregroundStyle(.secondary).padding(32) }
            else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
                        ForEach(contents.files) { file in
                            Button {
                                NSWorkspace.shared.open(file.url)
                                close()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 48, height: 48)
                                    Text(file.name).font(.caption).lineLimit(2).multilineTextAlignment(.center).frame(height: 30)
                                }.frame(width: 82)
                            }.buttonStyle(.plain).help(file.name)
                        }
                    }.padding(.vertical, 4)
                }.frame(maxHeight: 380)
            }
        }.padding(18).frame(width: 400).onAppear { contents.load() }
    }
}

// Keep one directory request per app, including while a system permission prompt
// is pending. Opening/closing the popover must not accumulate blocked workers.
@MainActor private final class FolderContents: ObservableObject {
    let folder: URL
    @Published var files: [StackFile] = []
    @Published var loading = true
    @Published var waitingForAccess = false
    @Published var error: String?
    private var request: Task<Void, Never>?
    init(folder: URL) { self.folder = folder }
    func load() {
        guard request == nil else { return }
        loading = true
        waitingForAccess = false
        request = Task { @MainActor in
            let waiting = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled && loading { waitingForAccess = true }
            }
            let folder = self.folder
            let result: Result<[StackFile], Error> = await Task.detached {
            Result {
                let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                return urls.map { url in StackFile(url: url, name: url.lastPathComponent,
                                                  date: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
                    .sorted { $0.date > $1.date }.prefix(80).map { $0 }
            }
            }.value
            waiting.cancel()
            switch result { case .success(let value): files = value; error = nil; case .failure: error = "다운로드 폴더를 읽을 수 없습니다. 폴더 접근을 허용해 주세요." }
            loading = false
            waitingForAccess = false
            request = nil
        }
    }
}
