import AppKit

/// Raster work runs only when artwork changes, display scale changes, or a failed load retries.
@MainActor enum DockArtwork {
    static func render(_ image: NSImage, scale: CGFloat) -> CGImage? {
        guard image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else { return nil }
        let side = Int(ceil(72 * 4 * scale))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill(using: .copy)
        let aspect = image.size.width / image.size.height
        let size = NSSize(width: aspect >= 1 ? CGFloat(side) : CGFloat(side) * aspect,
                          height: aspect >= 1 ? CGFloat(side) / aspect : CGFloat(side))
        image.draw(in: NSRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2,
                             width: size.width, height: size.height),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        // A successful allocation is not proof that IconServices supplied artwork.
        guard let bytes = bitmap.bitmapData else { return nil }
        for y in 0..<side {
            for x in 0..<side where bytes[y * bitmap.bytesPerRow + x * 4 + 3] != 0 {
                return bitmap.cgImage
            }
        }
        return nil
    }

    static let placeholder = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { _ in
        NSColor.systemGray.setFill()
        NSBezierPath(roundedRect: NSRect(x: 3, y: 3, width: 26, height: 26), xRadius: 6, yRadius: 6).fill()
        NSColor.white.setStroke()
        let outline = NSBezierPath(roundedRect: NSRect(x: 9, y: 9, width: 14, height: 14), xRadius: 2, yRadius: 2)
        outline.lineWidth = 2
        outline.stroke()
        return true
    }
}
