import AppKit

/// The background and text have separate bounds: a tall NSTextField cell aligns to its top.
@MainActor final class DockTooltip: NSView {
    private let label = NSTextField(labelWithString: "")
    var stringValue: String {
        get { label.stringValue }
        set { label.stringValue = newValue; needsLayout = true }
    }
    var textFrame: NSRect { label.frame }
    override var intrinsicContentSize: NSSize { label.intrinsicContentSize }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setAccessibilityElement(false)
        addSubview(label)
        updateLayer()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func layout() {
        super.layout()
        let height = min(bounds.height, label.intrinsicContentSize.height)
        label.frame = NSRect(x: 7, y: (bounds.height - height) / 2, width: max(0, bounds.width - 14), height: height)
    }
}
