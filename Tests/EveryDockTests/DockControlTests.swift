import AppKit
import Testing
@testable import EveryDock

@MainActor private final class ClickReceiver: NSObject {
    var count = 0
    @objc func clicked(_ sender: Any?) { count += 1 }
}

@MainActor private func mouse(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
    NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                      windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
}

@MainActor @Test func iconControlCancelsReleaseOutsideAndTracksDragBackInside() {
    let control = DockIconButton(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
    let receiver = ClickReceiver()
    control.target = receiver
    control.action = #selector(ClickReceiver.clicked(_:))
    control.mouseDown(with: mouse(.leftMouseDown, NSPoint(x: 24, y: 24)))
    control.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 90, y: 90)))
    control.mouseUp(with: mouse(.leftMouseUp, NSPoint(x: 90, y: 90)))
    #expect(receiver.count == 0)
    #expect(DockIconButton.trackingButton == nil)
    control.mouseDown(with: mouse(.leftMouseDown, NSPoint(x: 24, y: 24)))
    control.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 90, y: 90)))
    control.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 24, y: 24)))
    control.mouseUp(with: mouse(.leftMouseUp, NSPoint(x: 24, y: 24)))
    #expect(receiver.count == 1)
    #expect(DockIconButton.trackingButton == nil)
}

@MainActor @Test func iconControlSupportsAccessibilityPressWithoutMouseTracking() {
    let control = DockIconButton(frame: .zero)
    let receiver = ClickReceiver()
    control.target = receiver
    control.action = #selector(ClickReceiver.clicked(_:))
    #expect(control.accessibilityPerformPress())
    #expect(receiver.count == 1)
    #expect(DockIconButton.trackingButton == nil)
}

@MainActor @Test func iconControlSupportsSpaceAndReturn() {
    let control = DockIconButton(frame: .zero)
    let receiver = ClickReceiver()
    control.target = receiver
    control.action = #selector(ClickReceiver.clicked(_:))
    for code: UInt16 in [49, 36] {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                    windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ",
                                    isARepeat: false, keyCode: code)!
        control.keyDown(with: event)
    }
    #expect(receiver.count == 2)
}

@MainActor @Test func tooltipCentersTextVerticallyAtDifferentHeights() {
    let tooltip = DockTooltip(frame: .zero)
    for title in ["Finder", "미리보기", "Downloads and Documents"] {
        tooltip.stringValue = title
        for height in [26.0, 32.0, 40.0] {
            tooltip.frame = NSRect(x: 0, y: 0, width: 220, height: height)
            tooltip.layout()
            #expect(abs(tooltip.textFrame.midY - tooltip.bounds.midY) < 0.01)
            #expect(tooltip.textFrame.height <= height)
        }
    }
}
