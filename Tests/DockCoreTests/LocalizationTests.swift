import Foundation
import Testing
@testable import DockCore

@Test func languageSelectionResolvesPrimarySystemLanguageAndExplicitOverrides() {
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ko-KR", "en-US"]) == .korean)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ko"]) == .korean)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["en-US", "ko-KR"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP", "ko"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
    #expect(AppLanguage.english.resolved(preferredLanguages: ["ko-KR"]) == .english)
    #expect(AppLanguage.korean.resolved(preferredLanguages: ["en-US"]) == .korean)
}

@Test func newDefaultsAndLanguageMigrationPreserveSavedChoices() throws {
    for preferences in [DockPreferences(), try JSONDecoder().decode(DockPreferences.self, from: Data("{}".utf8))] {
        #expect(!preferences.showOnFullScreen)
        #expect(preferences.previewDelay == 0.60)
        #expect(preferences.language == .system)
    }
    let previous = try JSONDecoder().decode(DockPreferences.self,
        from: Data(#"{"showOnFullScreen":true,"previewDelay":0.55,"language":"unsupported"}"#.utf8))
    #expect(previous.showOnFullScreen)
    #expect(previous.previewDelay == 0.55)
    #expect(previous.language == .system)
    for language in AppLanguage.allCases {
        var preferences = previous
        preferences.language = language
        let restored = try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored == preferences)
    }
    var invalid = DockPreferences()
    invalid.previewDelay = .nan
    invalid.normalize()
    #expect(invalid.previewDelay == 0.60)
}

@Test func localizedInterpolationPreservesExternalNamesAndFallsBackToEnglish() {
    let name = "Finder {1} 한국어"
    #expect(L10n.render("Open \(name)", language: .korean) == "\(name) 열기")
    #expect(L10n.render("Open \(name)", language: .english) == "Open \(name)")
    #expect(L10n.render("Unknown label \(name)", language: .korean) == "Unknown label \(name)")
    #expect(L10n.render("Language", language: .korean) == "언어")
    #expect(L10n.render("1 window", language: .korean) == "창 1개")
    #expect(L10n.render("\(3) windows", language: .korean) == "창 3개")
}

@Test func koreanCatalogPreservesAllInterpolationTokens() throws {
    let expression = try NSRegularExpression(pattern: #"\{\d+\}"#)
    func tokens(_ value: String) -> [String] {
        expression.matches(in: value, range: NSRange(value.startIndex..., in: value))
            .map { (value as NSString).substring(with: $0.range) }.sorted()
    }
    #expect(L10n.korean.count >= 160)
    for (english, korean) in L10n.korean {
        #expect(!korean.isEmpty)
        #expect(tokens(english) == tokens(korean), "Interpolation mismatch: \(english)")
    }
}
