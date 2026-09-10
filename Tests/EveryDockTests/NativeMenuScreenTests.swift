import Foundation
import Testing
@testable import EveryDock

@Test func nativeMenuNeverOpensOnAnotherMonitor() {
    let left = CGRect(x: -1512, y: 0, width: 1512, height: 982)
    let right = CGRect(x: 0, y: 0, width: 2304, height: 1296)
    let point = CGPoint(x: 1000, y: 1320)
    #expect(NativeMenuScreen.matches(point: point, target: right, screens: [left, right]))
    #expect(!NativeMenuScreen.matches(point: point, target: left, screens: [left, right]))
    #expect(!NativeMenuScreen.matches(point: CGPoint(x: CGFloat.infinity, y: 0), target: right, screens: [right]))
}
