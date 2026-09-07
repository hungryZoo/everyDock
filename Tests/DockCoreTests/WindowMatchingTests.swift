import Foundation
import Testing
@testable import DockCore

private let first = CGRect(x: -1400, y: 50, width: 800, height: 600)
private let second = CGRect(x: 100, y: 80, width: 900, height: 700)

@Test func captureMetadataNeverAddsGhostWindows() {
    let result = WindowMatching.match(windows: [.init(title: "New title", frame: first)], captures: [
        .init(title: "Old title", frame: first), .init(title: "Helper", frame: second), .init(title: "", frame: first)
    ])
    #expect(result.count == 1)
    #expect(result[0] == 0)
    #expect(WindowMatching.match(windows: [], captures: [.init(title: "Ghost", frame: first)]).isEmpty)
}
@Test func sameTitleWindowsKeepSeparateOneToOneImages() {
    let result = WindowMatching.match(windows: [.init(title: "Downloads", frame: first), .init(title: "Downloads", frame: second)],
                                      captures: [.init(title: "Downloads", frame: second), .init(title: "Downloads", frame: first)])
    #expect(result == [0: 1, 1: 0])
}
@Test func missingMinimizedAndMovedWindowsDoNotBorrowAnotherImage() {
    let moved = first.offsetBy(dx: 100, dy: 0)
    let result = WindowMatching.match(windows: [.init(title: "Same", frame: first), .init(title: "Minimized", frame: second)],
                                      captures: [.init(title: "Same", frame: moved)])
    #expect(result.isEmpty)
}
@Test func menuPlacementUsesIconEdgeAndClampsNegativeScreens() {
    let screen = CGRect(x: -2304, y: -100, width: 2304, height: 1296)
    let menu = CGSize(width: 220, height: 250)
    let anchor = CGRect(x: -1200, y: -90, width: 80, height: 80)
    let point = DockMenuPlacement.topLeft(anchor: anchor, menu: menu, edge: .bottom, screen: screen)
    #expect(point.x + menu.width / 2 == anchor.midX)
    #expect(point.y - menu.height == anchor.maxY + 6)
    for edge in [DockEdge.bottom, .left, .right] {
        for rect in [anchor, CGRect(x: -2304, y: 1150, width: 100, height: 100), CGRect(x: -50, y: -100, width: 50, height: 50)] {
            let top = DockMenuPlacement.topLeft(anchor: rect, menu: menu, edge: edge, screen: screen)
            #expect(screen.contains(CGRect(x: top.x, y: top.y - menu.height, width: menu.width, height: menu.height)))
        }
    }
}
