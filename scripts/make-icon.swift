import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let outer = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 206, yRadius: 206)
    NSGradient(starting: NSColor(red: 0.26, green: 0.27, blue: 0.88, alpha: 1),
               ending: NSColor(red: 0.08, green: 0.73, blue: 0.87, alpha: 1))!.draw(in: outer, angle: -40)
    for x: CGFloat in [175, 531] {
        let screen = NSBezierPath(roundedRect: NSRect(x: x, y: 365, width: 318, height: 296), xRadius: 38, yRadius: 38)
        NSColor.white.withAlphaComponent(0.16).setFill()
        screen.fill()
        NSColor.white.withAlphaComponent(0.92).setStroke()
        screen.lineWidth = 16
        screen.stroke()
        let stand = NSBezierPath(roundedRect: NSRect(x: x + 110, y: 311, width: 98, height: 15), xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(0.9).setFill()
        stand.fill()
        NSBezierPath(rect: NSRect(x: x + 151, y: 325, width: 16, height: 35)).fill()
        let dock = NSBezierPath(roundedRect: NSRect(x: x + 32, y: 389, width: 254, height: 67), xRadius: 21, yRadius: 21)
        NSColor.white.withAlphaComponent(0.3).setFill()
        dock.fill()
        for index in 0..<4 {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: x + 48 + CGFloat(index) * 57, y: 404, width: 36, height: 36), xRadius: 9, yRadius: 9).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size).write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size).png"))
    try drawIcon(size: size * 2).write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)@2x.png"))
}
