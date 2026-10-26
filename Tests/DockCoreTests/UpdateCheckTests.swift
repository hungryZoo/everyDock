import Foundation
import Testing
@testable import DockCore

@Test func semanticVersionParsesOnlyPlainReleaseVersions() {
    #expect(SemanticVersion("1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(SemanticVersion("v1.0.10") == SemanticVersion(major: 1, minor: 0, patch: 10))
    #expect(SemanticVersion("1.2") == nil)
    #expect(SemanticVersion("1.2.3-rc1") == nil)
    #expect(SemanticVersion("1.+2.3") == nil)
    #expect(SemanticVersion("") == nil)
    #expect(SemanticVersion("1.0.9")! < SemanticVersion("1.0.10")!)
    #expect(SemanticVersion("1.9.9")! < SemanticVersion("2.0.0")!)
    #expect(!(SemanticVersion("1.0.0")! < SemanticVersion("1.0.0")!))
}

@Test func updateCheckRunsAtMostOncePerDay() {
    #expect(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 0))
    #expect(!UpdatePolicy.shouldCheck(now: 100_000, checkedAt: 100_000 - 3_600))
    #expect(UpdatePolicy.shouldCheck(now: 200_000, checkedAt: 200_000 - 86_400))
    #expect(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 5_000))
}

@Test func pendingUpdateRespectsCurrentAndSkippedVersions() {
    let current = SemanticVersion("1.0.0")!
    let cache = UpdateCache(checkedAt: 1, latestVersion: "1.1.0")
    #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: nil) == SemanticVersion("1.1.0"))
    #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.1.0") == nil)
    #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.0.5") == SemanticVersion("1.1.0"))
    #expect(UpdatePolicy.pendingUpdate(current: SemanticVersion("1.1.0")!, cache: cache, skippedVersion: nil) == nil)
    #expect(UpdatePolicy.pendingUpdate(current: current, cache: UpdateCache(), skippedVersion: nil) == nil)
}

@Test func updateCacheRoundTripsAndTreatsCorruptFilesAsUnchecked() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("everyDock-update-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = UpdateCacheStore(fileURL: directory.appendingPathComponent("nested/update-check.json"))
    #expect(store.load() == UpdateCache())
    let cache = UpdateCache(checkedAt: 42, latestVersion: "1.1.0", releaseNotes: "Line 1\n줄 2", releaseURL: "https://example.com")
    try store.save(cache)
    #expect(store.load() == cache)
    try Data("not json".utf8).write(to: store.fileURL)
    #expect(store.load() == UpdateCache())
    #expect(UpdateCacheStore.defaultFileURL()?.path.hasSuffix("Library/Caches/app.everydock.mac/update-check.json") == true)
}

@Test func latestReleaseParserRejectsPrereleasesAndErrors() {
    let json = ##"{"tag_name":"v1.1.0","body":"Intro\n## New\n- Item","html_url":"https://github.com/hungryZoo/everyDock/releases/tag/v1.1.0","draft":false,"prerelease":false}"##
    let release = LatestReleaseParser.parse(Data(json.utf8))
    #expect(release?.version == SemanticVersion("1.1.0"))
    #expect(release?.notes == "Intro\n## New\n- Item")
    #expect(release?.url.absoluteString == "https://github.com/hungryZoo/everyDock/releases/tag/v1.1.0")
    #expect(LatestReleaseParser.parse(Data(json.replacingOccurrences(of: #""prerelease":false"#, with: #""prerelease":true"#).utf8)) == nil)
    #expect(LatestReleaseParser.parse(Data(json.replacingOccurrences(of: "v1.1.0\",\"body", with: "nightly\",\"body").utf8)) == nil)
    #expect(LatestReleaseParser.parse(Data(#"{"message":"API rate limit exceeded"}"#.utf8)) == nil)
}

@Test func releaseNotesBecomeInlineMarkdown() {
    let body = """
    First sentence.

    ## What's new

    - **One change.** Detail
      - Nested item


    ```bash
    brew upgrade --cask hungryZoo/tap/everydock
    ```
    """
    #expect(ReleaseNotesFormatter.inlineMarkdown(body)
            == "First sentence.\n\n**What's new**\n\n• **One change.** Detail\n    • Nested item\n\nbrew upgrade --cask hungryZoo/tap/everydock")
}

@Test func installMethodRequiresCaskLocationAndCaskroomRecord() {
    let cask: Set<String> = ["/opt/homebrew/Caskroom/everydock", "/opt/homebrew/bin/brew"]
    #expect(InstallMethod.classify(appPath: "/Applications/everyDock.app", homeDirectory: "/Users/u", fileExists: cask.contains)
            == .homebrew(brewPath: "/opt/homebrew/bin/brew"))
    #expect(InstallMethod.classify(appPath: "/Users/u/Applications/everyDock.app", homeDirectory: "/Users/u/", fileExists: cask.contains)
            == .homebrew(brewPath: "/opt/homebrew/bin/brew"))
    #expect(InstallMethod.classify(appPath: "/Applications/everyDock.app", homeDirectory: "/Users/u", fileExists: { _ in false }) == .manual)
    #expect(InstallMethod.classify(appPath: "/Users/u/dev/everyDock/dist/everyDock.app", homeDirectory: "/Users/u", fileExists: cask.contains) == .manual)
}

@Test func homebrewScriptWaitsForQuitAndUsesFullCaskName() {
    let script = UpdateScript.homebrew(brewPath: "/opt/homebrew/bin/brew", appPath: "/Users/o'neil/Applications/everyDock.app", waitForPID: 123)
    #expect(script.hasPrefix("#!/bin/zsh\n"))
    #expect(script.contains("while kill -0 123 2>/dev/null"))
    let update = script.range(of: "'/opt/homebrew/bin/brew' update\n")
    let upgrade = script.range(of: "'/opt/homebrew/bin/brew' upgrade --cask hungryZoo/tap/everydock")
    #expect(update != nil && upgrade != nil && update!.lowerBound < upgrade!.lowerBound)
    #expect(script.contains("open '/Users/o'\\''neil/Applications/everyDock.app'"))
    #expect(script.contains("rm -f -- \"$0\""))
    #expect(!script.contains("reinstall"))
}

@Test func updatePreferencesDefaultOnAndRoundTrip() throws {
    let legacy = try JSONDecoder().decode(DockPreferences.self, from: Data("{}".utf8))
    #expect(legacy.checkForUpdates)
    #expect(legacy.skippedUpdateVersion == nil)
    var preferences = DockPreferences()
    preferences.checkForUpdates = false
    preferences.skippedUpdateVersion = "1.1.0"
    #expect(try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(preferences)) == preferences)
}
