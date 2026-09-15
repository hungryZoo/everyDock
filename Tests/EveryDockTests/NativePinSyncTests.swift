import Foundation
import Testing
import DockCore
@testable import EveryDock

@Test func nativePinSyncWritesOnlyAppTilesAndRejectsMalformedState() async throws {
    let domain = "app.everydock.test.native-pins.\(UUID().uuidString)"
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let app = folder.appendingPathComponent("Fixture.app")
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
    func write(_ key: String, _ value: CFPropertyList) {
        CFPreferencesSetValue(key as CFString, value, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    defer {
        UserDefaults.standard.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: folder)
    }
    write("persistent-others", ["keep-this-folder"] as CFArray)
    write("autohide", true as CFBoolean)
    let sync = NativeDockPinSync(preferenceDomain: domain)
    let changed = try await sync.apply(pins: [.init(path: app.path, bundleIdentifier: "test.fixture")], removing: [])
    #expect(changed)
    let same = try await sync.apply(pins: [.init(path: app.path, bundleIdentifier: "test.fixture")], removing: [])
    #expect(!same)
    let others = CFPreferencesCopyValue("persistent-others" as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]
    #expect(others == ["keep-this-folder"])
    let hidden = CFPreferencesCopyValue("autohide" as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool
    #expect(hidden == true)
    write("persistent-apps", "unexpected-schema" as CFString)
    do {
        _ = try await sync.apply(pins: [], removing: [])
        Issue.record("Malformed preferences were overwritten")
    } catch NativeDockPinSync.Failure.unsupportedPreferences {}
    let invalid = CFPreferencesCopyValue("persistent-apps" as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? String
    #expect(invalid == "unexpected-schema")
}

@Test func nativePinsReadExternalChangesAfterReopeningAndDistinguishEmptyFromMissing() async throws {
    let domain = "app.everydock.test.native-read.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: domain) }
    func write(_ value: CFPropertyList) {
        CFPreferencesSetValue("persistent-apps" as CFString, value, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    let reader = NativeDockPinSync(preferenceDomain: domain)
    let missing = try await reader.read()
    #expect(missing == nil)
    let a = PinnedApplication(path: "/Applications/A.app", bundleIdentifier: "test.A")
    let b = PinnedApplication(path: "/Applications/B.app", bundleIdentifier: "test.B")
    let separator = PinnedApplication(separatorID: UUID())
    write(NativeDockPins.reordered([], pins: [a, b]) as CFArray)
    let first = try #require(await reader.read())
    #expect(first == [a, b])
    // Simulate the native Dock writing while everyDock is absent, then a new reader.
    write(NativeDockPins.reordered([], pins: [b, a]) as CFArray)
    let reopened = NativeDockPinSync(preferenceDomain: domain)
    let second = try #require(await reopened.read())
    #expect(NativeDockPins.importing(second, into: [a, separator, b]) == [b, separator, a])
    write([] as CFArray)
    let empty = try await reader.read()
    #expect(empty == [])
    write("invalid" as CFString)
    do {
        _ = try await reopened.read()
        Issue.record("Invalid native state accepted as an empty list")
    } catch NativeDockPinSync.Failure.unsupportedPreferences {}
}
