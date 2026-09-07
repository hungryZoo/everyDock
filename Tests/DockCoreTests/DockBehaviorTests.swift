import Foundation
import Testing
@testable import DockCore

@Test func magnificationIsContinuousAndAffectsNeighbors() {
    #expect(DockMotion.scale(distance: 0, iconSize: 48, magnification: 1.65) == 1.65)
    #expect(DockMotion.scale(distance: 58, iconSize: 48, magnification: 1.65) > 1.3)
    #expect(DockMotion.scale(distance: 1000, iconSize: 48, magnification: 1.65) == 1)
    for distance in stride(from: 0.0, through: 200.0, by: 5) {
        let left = DockMotion.scale(distance: -distance, iconSize: 48, magnification: 2)
        let right = DockMotion.scale(distance: distance, iconSize: 48, magnification: 2)
        #expect(left == right)
        #expect((1...2).contains(left))
    }
}

@Test func oldPreferencesMigrateWithoutLosingPins() throws {
    let data = Data(#"{"iconSize":64,"inset":12,"edge":"left","showRunningApps":false,"showOnFullScreen":true,"hiddenDisplayIDs":["test"],"pinnedApps":[{"path":"/Applications/A.app","bundleIdentifier":"a"}]}"#.utf8)
    let preferences = try JSONDecoder().decode(DockPreferences.self, from: data)
    #expect(preferences.iconSize == 64)
    #expect(preferences.pinnedApps.count == 1)
    #expect(preferences.edge == .left)
    #expect(preferences.manageNativeDock)
    #expect(preferences.clickToMinimize)
    #expect(preferences.magnification == 1.65)
}

@Test func recoveryRestoresAbsentValuesButPreservesUserEdits() throws {
    let snapshot = NativeDockSnapshot(
        original: ["autohide": .boolean(false), "autohide-delay": .absent, "autohide-time-modifier": .number(0.5)],
        applied: ["autohide": .boolean(true), "autohide-delay": .number(3600), "autohide-time-modifier": .number(0)])
    let restored = try JSONDecoder().decode(NativeDockSnapshot.self, from: JSONEncoder().encode(snapshot))
    let changes = restored.restoration(current: ["autohide": .boolean(true), "autohide-delay": .number(3600), "autohide-time-modifier": .number(2)])
    #expect(changes["autohide"] == .boolean(false))
    #expect(changes["autohide-delay"] == .absent)
    #expect(changes["autohide-time-modifier"] == nil)
}
