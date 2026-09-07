import Foundation
import Testing
@testable import DockCore

@Test func utilityTilesAreIncludedInDockWidth() {
    let oneMoreApp = DockMetrics.length(iconSize: 39, appCount: 18) - DockMetrics.length(iconSize: 39, appCount: 17)
    #expect(oneMoreApp == 41)
    #expect(DockMetrics.length(iconSize: 39, appCount: 0) == 147)
    #expect(DockMetrics.thickness(iconSize: 39) == 51)
}

@Test func nativeMagnificationIsNotClampedToTwoTimes() throws {
    let data = Data(#"{"magnification":2.6667,"followNativeSize":true,"showPreviews":true,"previewDelay":0.55}"#.utf8)
    let preferences = try JSONDecoder().decode(DockPreferences.self, from: data)
    #expect(preferences.magnification == 2.6667)
    #expect(preferences.followNativeSize)
    #expect(preferences.showPreviews)
}

@Test func genieSettingParticipatesInSafeRecovery() throws {
    let snapshot = NativeDockSnapshot(original: ["mineffect": .string("scale")], applied: ["mineffect": .string("genie")])
    let decoded = try JSONDecoder().decode(NativeDockSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(decoded.restoration(current: ["mineffect": .string("genie")])["mineffect"] == .string("scale"))
    #expect(decoded.restoration(current: ["mineffect": .string("suck")]).isEmpty)
}
