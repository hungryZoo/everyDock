import Foundation
import Testing
@testable import DockCore

@Test func uninstallClearsEntirePreferenceDomainAndFirstRunHistory() throws {
    let domain = "app.everydock.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set(true, forKey: "everyDock.hasLaunched")
    defaults.set(Data("old options".utf8), forKey: "everyDock.preferences.v1")
    defaults.set("window frame", forKey: "NSWindow Frame everyDock.settings")
    defaults.synchronize()
    PreferenceReset.clear(domain: domain, defaults: defaults)
    let fresh = try #require(UserDefaults(suiteName: domain))
    #expect(fresh.object(forKey: "everyDock.hasLaunched") == nil)
    #expect(fresh.object(forKey: "everyDock.preferences.v1") == nil)
    #expect(fresh.object(forKey: "NSWindow Frame everyDock.settings") == nil)
}

@Test func missingPermissionsAlwaysReopenGuidanceEvenAfterOnboarding() {
    for login in [false, true] {
        for hidden in [false, true] {
            #expect(StartupPresentation.resolve(hasLaunched: true, loginLaunch: login, hidesMenuIcon: hidden,
                                               needsPermissionGuidance: true) == .onboarding)
        }
    }
}
