import Foundation
import Testing
@testable import DockCore

private let maximum = CGRect(x: 0, y: 25, width: 1512, height: 957)
private let area = WindowWorkArea(visible: maximum, dockBoundary: 928, edge: .bottom)
private let original = CGRect(x: 100, y: 200, width: 600, height: 400)

@Test func correctedZoomRestoresOriginalForThreeCycles() {
    var state = WindowZoomState()
    state.observe(original, in: [area])
    for _ in 0..<3 {
        #expect(state.destination(for: maximum, in: [area]) == area.usable)
        #expect(state.destination(for: area.usable, in: [area]) == nil)
        // App forgot its zoom flag and expands again on the second double click.
        #expect(state.destination(for: maximum, in: [area]) == original)
        #expect(state.destination(for: original, in: [area]) == nil)
    }
}
@Test func nativeRestoreAndManualResizeUpdateTheSavedFrame() {
    var state = WindowZoomState()
    state.observe(original, in: [area])
    _ = state.destination(for: maximum, in: [area])
    #expect(state.destination(for: original, in: [area]) == nil)
    let moved = original.offsetBy(dx: 70, dy: 30)
    #expect(state.destination(for: moved, in: [area]) == nil)
    _ = state.destination(for: maximum, in: [area])
    #expect(state.destination(for: maximum, in: [area]) == moved)
}
@Test func observerReattachmentPreservesRestoreAndUnknownHistoryIsNotInvented() {
    var state = WindowZoomState()
    state.observe(original, in: [area])
    _ = state.destination(for: maximum, in: [area])
    state.observe(area.usable, in: [area])
    #expect(state.destination(for: maximum, in: [area]) == original)
    var unknown = WindowZoomState()
    unknown.observe(maximum, in: [area])
    #expect(unknown.normal == nil && unknown.fitted == nil)
    #expect(unknown.destination(for: maximum, in: [area]) == area.usable)
    #expect(unknown.destination(for: maximum, in: [area]) == area.usable)
}
@Test func sideZoomRestoresPositionAndSizeWithoutMovingToDisconnectedDisplay() {
    let screen = CGRect(x: -1512, y: 25, width: 1512, height: 957)
    let side = WindowWorkArea(visible: screen, dockBoundary: -1458, edge: .left)
    let before = original.offsetBy(dx: -1512, dy: 0)
    var state = WindowZoomState()
    state.observe(before, in: [side])
    #expect(state.destination(for: screen, in: [side]) == side.usable)
    #expect(state.destination(for: screen, in: [side]) == before)
    _ = state.destination(for: screen, in: [side])
    #expect(state.destination(for: maximum, in: [area]) == area.usable)
}
@Test func newestModifiedFilesSortFirstWithStableNameTies() {
    let now = Date(), old = now.addingTimeInterval(-10)
    #expect(FileOrdering.precedes(date: now, name: "z.png", otherDate: old, otherName: "a.png"))
    #expect(!FileOrdering.precedes(date: old, name: "a.png", otherDate: now, otherName: "z.png"))
    #expect(FileOrdering.precedes(date: now, name: "file2.png", otherDate: now, otherName: "file10.png"))
    #expect(!FileOrdering.precedes(date: now, name: "same.png", otherDate: now, otherName: "same.png"))
}

@Test func restoreAnimationHasExactEndpointsAndMonotonicGeometry() {
    #expect(WindowFrameAnimation.frame(from: maximum, to: original, progress: -1) == maximum)
    #expect(WindowFrameAnimation.frame(from: maximum, to: original, progress: 2) == original)
    var previous = maximum
    for step in 1...60 {
        let frame = WindowFrameAnimation.frame(from: maximum, to: original, progress: Double(step) / 60)
        #expect(frame.width <= previous.width && frame.height <= previous.height)
        #expect(frame.minX >= previous.minX && frame.minY >= previous.minY)
        previous = frame
    }
}
