import Foundation
import Testing
@testable import DockCore

@Test func previewFitsOneTwoAndManyWindows() {
    let one = PreviewLayout(count: 1), two = PreviewLayout(count: 2), many = PreviewLayout(count: 9)
    #expect(one.columns == 1 && one.width == 222 && one.gridHeight == 160)
    #expect(two.columns == 2 && two.width == 424 && two.gridHeight == 160)
    #expect(many.columns == 2 && many.gridHeight == 340)
    #expect(PreviewLayout(count: 0).gridHeight == 0)
}
@Test func bottomZoomReservesOnlyRestingDockAndIsIdempotent() {
    let visible = CGRect(x: -2304, y: 25, width: 2304, height: 1271)
    let area = WindowWorkArea(visible: visible, dockBoundary: 1238, edge: .bottom)
    let result = area.adjusted(visible, fullScreen: false, minimized: false)!
    #expect(result.minY == visible.minY && result.width == visible.width && result.maxY == 1238)
    #expect(area.adjusted(result, fullScreen: false, minimized: false) == nil)
}
@Test func workAreaPreservesNormalMinimizedAndFullScreenWindows() {
    let frame = CGRect(x: 0, y: 25, width: 1512, height: 957)
    let area = WindowWorkArea(visible: frame, dockBoundary: 920, edge: .bottom)
    #expect(area.adjusted(frame, fullScreen: true, minimized: false) == nil)
    #expect(area.adjusted(frame, fullScreen: false, minimized: true) == nil)
    #expect(area.adjusted(CGRect(x: 100, y: 100, width: 800, height: 882), fullScreen: false, minimized: false) == nil)
}
@Test func sideDockReservesCorrectEdgeOnNegativeDisplays() {
    let frame = CGRect(x: -1512, y: -957, width: 1512, height: 900)
    let left = WindowWorkArea(visible: frame, dockBoundary: -1450, edge: .left)
    let right = WindowWorkArea(visible: frame, dockBoundary: -62, edge: .right)
    #expect(left.adjusted(frame, fullScreen: false, minimized: false)?.minX == -1450)
    #expect(right.adjusted(frame, fullScreen: false, minimized: false)?.maxX == -62)
}
