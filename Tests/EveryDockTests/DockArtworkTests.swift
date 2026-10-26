import AppKit
import Testing
@testable import EveryDock

@MainActor private func artwork(_ color: NSColor?) -> NSImage {
    NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
        if let color { color.setFill(); rect.fill() }
        return true
    }
}

@MainActor private final class ReloadableIcon: DockIconButton {
    var replacement: NSImage?
    override func freshArtwork() -> NSImage? { replacement ?? super.freshArtwork() }
}

@MainActor @Test func blankIconUsesPlaceholderAndRecoversFromFreshSource() {
    let control = ReloadableIcon(frame: .zero)
    control.setArtwork(artwork(nil))
    #expect(control.artworkNeedsRetry)
    let fallback = control.layer!.contents as! CGImage
    #expect(NSBitmapImageRep(cgImage: fallback).colorAt(x: 288, y: 288)!.alphaComponent > 0)
    control.replacement = artwork(.green)
    control.retryArtwork()
    #expect(!control.artworkNeedsRetry)
    #expect(control.artworkRetryCount == 1)
    let recovered = control.layer!.contents as! CGImage
    #expect(recovered !== fallback)
    let color = NSBitmapImageRep(cgImage: recovered).colorAt(x: 288, y: 288)!.usingColorSpace(.deviceRGB)!
    #expect(color.greenComponent > 0.95)
}

@MainActor @Test func failedIconRefreshKeepsGoodPixelsAndBoundsRetries() {
    let control = ReloadableIcon(frame: .zero)
    control.setArtwork(artwork(.red))
    let original = control.layer!.contents as! CGImage
    let blank = artwork(nil)
    control.setArtwork(blank)
    for _ in 0..<10 { control.retryArtwork(); control.setArtwork(blank) }
    #expect(control.artworkNeedsRetry)
    #expect(control.artworkRetryCount == 3)
    #expect((control.layer!.contents as! CGImage) === original)
}

@MainActor @Test func sameIconRestoresDiscardedLayerWithoutRasterizingAgain() {
    let image = artwork(.green)
    let control = DockIconButton(frame: .zero)
    control.setArtwork(image)
    let original = control.layer!.contents as! CGImage
    control.layer!.contents = nil
    control.setArtwork(image)
    #expect((control.layer!.contents as! CGImage) === original)
    #expect(control.artworkRetryCount == 0)
}

@MainActor @Test func iconRasterRejectsEmptyAndInvalidSizeButKeepsSparseArtwork() {
    #expect(DockArtwork.render(artwork(nil), scale: 2) == nil)
    #expect(DockArtwork.render(NSImage(size: .zero), scale: 2) == nil)
    let sparse = NSImage(size: NSSize(width: 576, height: 576), flipped: false) { _ in
        NSColor.blue.setFill()
        NSRect(x: 173, y: 211, width: 1, height: 1).fill()
        return true
    }
    #expect(DockArtwork.render(sparse, scale: 2) != nil)
}
