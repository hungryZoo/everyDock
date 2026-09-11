import AppKit
import Testing
@testable import EveryDock

private actor DirectoryGate {
    private var pending: CheckedContinuation<Result<[StackFile], Error>, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    func read(_ url: URL) async -> Result<[StackFile], Error> {
        calls += 1
        return await withCheckedContinuation { continuation in
            pending = continuation
            started?.resume(); started = nil
        }
    }
    func waitForStart() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func complete(_ files: [StackFile]) { pending?.resume(returning: .success(files)); pending = nil }
}

@Test @MainActor func latePopoverCloseCannotCancelReopenedFolder() async {
    let gate = DirectoryGate()
    let folder = FolderContents(folder: URL(fileURLWithPath: "/fixture"), title: "Fixture", symbol: "folder", readDirectory: { await gate.read($0) })
    let first = folder.beginPresentation()
    folder.load(for: first)
    await gate.waitForStart()
    let reopened = folder.beginPresentation()
    folder.load(for: reopened)
    folder.endPresentation(first) // Delayed disappearance of the old SwiftUI view.
    #expect(folder.presentation == reopened)
    #expect(await gate.calls == 1)
    let file = StackFile(url: URL(fileURLWithPath: "/fixture/directory"), name: "Directory", date: .distantPast,
                         icon: NSImage(size: NSSize(width: 48, height: 48)), isDirectory: true)
    await gate.complete([file])
    await folder.request?.value
    #expect(folder.files.count == 1)
    #expect(!folder.loading)
    folder.load(for: first) // An obsolete onAppear must not start another directory read.
    #expect(await gate.calls == 1)
    folder.load(for: reopened)
    await gate.waitForStart()
    #expect(!folder.loading) // Cached grid stays visible during refresh.
    #expect(folder.files.first?.icon === file.icon)
    await gate.complete([file])
    await folder.request?.value
    folder.endPresentation(reopened)
    #expect(folder.presentation == nil)
}

// Explicit integration run uses only a disposable PNG; CI need not have a Quick Look service.
@Test(.enabled(if: ProcessInfo.processInfo.environment["EVERYDOCK_RUN_QL_TEST"] == "1"))
@MainActor func quickLookThumbnailSurvivesTenReopens() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("everyDock-thumbnail-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 48,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let bytes = try #require(bitmap.bitmapData)
    for x in 0..<64 { for y in 0..<48 {
        let offset = y * bitmap.bytesPerRow + x * 4
        bytes[offset] = 255; bytes[offset + 1] = 0; bytes[offset + 2] = 0; bytes[offset + 3] = 255
    } }
    let fileURL = directory.appendingPathComponent("fixture.png")
    try #require(bitmap.representation(using: .png, properties: [:])).write(to: fileURL)
    let file = StackFile(url: fileURL, name: "fixture.png", date: Date(), icon: NSImage(size: NSSize(width: 48, height: 48)), isDirectory: false)
    let folder = FolderContents(folder: directory, title: "Fixture", symbol: "folder", readDirectory: { _ in .success([file]) })
    var token = folder.beginPresentation()
    folder.load(for: token)
    await folder.request?.value
    let deadline = Date().addingTimeInterval(10)
    while folder.files.first?.icon === file.icon && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
    let thumbnail = try #require(folder.files.first?.icon)
    #expect(thumbnail !== file.icon)
    var rect = NSRect(x: 0, y: 0, width: 48, height: 48)
    let pixels = try #require(thumbnail.cgImage(forProposedRect: &rect, context: nil, hints: nil))
    let sample = NSBitmapImageRep(cgImage: pixels)
    let color = try #require(sample.colorAt(x: sample.pixelsWide / 2, y: sample.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
    #expect(color.redComponent > 0.8 && color.greenComponent < 0.2)
    for _ in 0..<10 {
        let previous = token
        token = folder.beginPresentation()
        folder.load(for: token)
        folder.endPresentation(previous)
        #expect(!folder.loading)
        await folder.request?.value
        #expect(folder.presentation == token)
        #expect(folder.files.first?.icon === thumbnail)
    }
    folder.endPresentation(token)
}
