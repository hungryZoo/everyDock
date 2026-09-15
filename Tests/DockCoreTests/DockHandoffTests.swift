import Foundation
import Testing
@testable import DockCore

@Test func externalDisplayPolicyHandlesLaptopDesktopMirroringAndOptOut() throws {
    #expect(DockActivity.automaticallyPaused(enabled: true, onlineDisplayBuiltIns: [true]))
    #expect(DockActivity.automaticallyPaused(enabled: true, onlineDisplayBuiltIns: []))
    #expect(!DockActivity.automaticallyPaused(enabled: true, onlineDisplayBuiltIns: [true, false]))
    #expect(!DockActivity.automaticallyPaused(enabled: true, onlineDisplayBuiltIns: [false]))
    #expect(!DockActivity.automaticallyPaused(enabled: false, onlineDisplayBuiltIns: [true]))
    let defaults = try JSONDecoder().decode(DockPreferences.self, from: Data("{}".utf8))
    #expect(defaults.pauseWithoutExternalDisplay)
    var saved = defaults
    saved.pauseWithoutExternalDisplay = false
    #expect(try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(saved)) == saved)
}

@Test func holdingDistinguishesClicksEarlyMovementAndCancellation() {
    var hold = DockHold()
    hold.begin(at: 10)
    let outcome1 = hold.arm(at: 10.1)
    #expect(!outcome1)
    let outcome2 = hold.end()
    #expect(!outcome2) // short release activates normally
    let outcome3 = hold.arm(at: 11)
    #expect(!outcome3) // delayed callback after release cannot arm
    hold.begin(at: 20)
    hold.move(distance: 7)
    let outcome4 = hold.arm(at: 21)
    #expect(!outcome4)
    let outcome5 = hold.end()
    #expect(!outcome5)
    hold.begin(at: 30)
    hold.move(distance: 2)
    let outcome6 = hold.arm(at: 30.31)
    #expect(outcome6)
    hold.move(distance: 100)
    #expect(hold.armed)
    let outcome7 = hold.end()
    #expect(outcome7) // hold release consumes the click
    #expect(!hold.armed)
}

private func tile(_ name: String) -> [String: Any] {
    ["GUID": name, "tile-type": "file-tile", "tile-data": [
        "file-data": ["_CFURLString": URL(fileURLWithPath: "/Applications/\(name).app").absoluteString, "_CFURLStringType": 15],
        "bundle-identifier": "test.\(name)", "preserve": "metadata"
    ]]
}
private func pin(_ name: String) -> PinnedApplication {
    .init(path: "/Applications/\(name).app", bundleIdentifier: "test.\(name)")
}

@Test func nativeOrderIgnoresEveryDockSeparatorsAndPreservesMetadataAndOtherTiles() {
    let spacer: [String: Any] = ["tile-type": "spacer-tile", "GUID": "spacer"]
    let other: [String: Any] = ["tile-type": "custom-tile", "GUID": "custom"]
    let finder = PinnedApplication(path: "/System/Library/CoreServices/Finder.app", bundleIdentifier: "com.apple.finder")
    let result = NativeDockPins.reordered([tile("A"), spacer, tile("B"), other, tile("C")],
        pins: [finder, pin("B"), .init(separatorID: UUID()), pin("A")])
    #expect(result.compactMap { NativeDockPins.path(of: $0) } == [pin("B").path, pin("A").path, pin("C").path])
    #expect((result[0] as NSDictionary).isEqual(to: tile("B")))
    #expect((result[1] as NSDictionary).isEqual(to: spacer))
    #expect((result[3] as NSDictionary).isEqual(to: other))
    let same = NativeDockPins.reordered(result, pins: [finder, pin("B"), pin("A")])
    #expect((result as NSArray).isEqual(to: same))
}

@Test func nativeOrderPinsNewAppsAndUnpinsOnlyTheRequestedApp() {
    let result = NativeDockPins.reordered([tile("A"), tile("C")], pins: [pin("B"), pin("B")], removing: [pin("A").path])
    #expect(result.compactMap { NativeDockPins.path(of: $0) } == [pin("B").path, pin("C").path])
    let data = result.first?["tile-data"] as? [String: Any]
    #expect(data?["bundle-identifier"] as? String == "test.B")
    #expect((result[1] as NSDictionary).isEqual(to: tile("C")))
    #expect(NativeDockPins.path(of: ["tile-type": "url-tile", "tile-data": ["file-data": ["_CFURLString": "https://example.com/A.app"]]]) == nil)
}

@Test func nativeImportReflectsReorderPinUnpinAndKeepsLocalSeparators() {
    let finder = PinnedApplication(path: "/System/Library/CoreServices/Finder.app", bundleIdentifier: "com.apple.finder")
    let separator = PinnedApplication(separatorID: UUID())
    let second = PinnedApplication(separatorID: UUID())
    let saved = [finder, pin("A"), separator, pin("B"), second, pin("C")]
    let imported = NativeDockPins.importing([pin("C"), pin("B"), pin("A")], into: saved)
    #expect(imported == [finder, pin("C"), separator, pin("B"), second, pin("A")])
    #expect(NativeDockPins.importing([pin("D"), pin("B"), pin("D")], into: imported) == [finder, pin("D"), separator, pin("B"), second])
    #expect(NativeDockPins.importing([], into: imported) == [finder, separator, second])
    let nativeAgain = NativeDockPins.reordered([tile("C"), tile("B"), tile("A")], pins: imported)
    #expect((nativeAgain as NSArray).isEqual(to: [tile("C"), tile("B"), tile("A")]))
    #expect(NativeDockPins.importing([pin("C"), pin("B"), pin("A")], into: imported) == imported)
}
