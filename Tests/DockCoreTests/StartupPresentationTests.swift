import Foundation
import Testing
@testable import DockCore

@Test func initialSetupAndHiddenMenuLaunchesHaveReachableWindows() {
    for hidden in [false, true] {
        #expect(StartupPresentation.resolve(hasLaunched: false, loginLaunch: false, hidesMenuIcon: hidden) == .onboarding)
        #expect(StartupPresentation.resolve(hasLaunched: false, loginLaunch: true, hidesMenuIcon: hidden) == .onboarding)
        #expect(StartupPresentation.resolve(hasLaunched: true, loginLaunch: true, hidesMenuIcon: hidden) == .background)
    }
    #expect(StartupPresentation.resolve(hasLaunched: true, loginLaunch: false, hidesMenuIcon: true) == .settings)
    #expect(StartupPresentation.resolve(hasLaunched: true, loginLaunch: false, hidesMenuIcon: false) == .background)
}

@Test func menuIconVisibilityMigratesAndPersistsWithoutChangingPins() throws {
    let legacy = Data(#"{"pinnedApps":[{"path":"/A.app","bundleIdentifier":"a"}]}"#.utf8)
    var preferences = try JSONDecoder().decode(DockPreferences.self, from: legacy)
    #expect(!preferences.hideMenuBarIcon)
    let originalPins = preferences.pinnedApps
    preferences.hideMenuBarIcon = true
    let restored = try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored.hideMenuBarIcon)
    #expect(restored.pinnedApps == originalPins)
}
