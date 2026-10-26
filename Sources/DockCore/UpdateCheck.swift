import Foundation

/// `MAJOR.MINOR.PATCH`. Accepts only a leading `v`; prerelease suffixes such as `-rc1` are rejected.
public struct SemanticVersion: Comparable, Hashable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ string: String) {
        var text = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            // Int("+1") parses, so require ASCII digits first.
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public struct LatestRelease: Equatable, Sendable {
    public let version: SemanticVersion
    public let notes: String
    public let url: URL

    public init(version: SemanticVersion, notes: String, url: URL) {
        self.version = version
        self.notes = notes
        self.url = url
    }
}

/// Last update check. `checkedAt` is the attempt time regardless of success; 0 means never checked.
public struct UpdateCache: Codable, Equatable, Sendable {
    public var checkedAt: TimeInterval
    public var latestVersion: String?
    public var releaseNotes: String?
    public var releaseURL: String?

    public init(checkedAt: TimeInterval = 0, latestVersion: String? = nil, releaseNotes: String? = nil, releaseURL: String? = nil) {
        self.checkedAt = checkedAt
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
        self.releaseURL = releaseURL
    }

    public mutating func record(_ release: LatestRelease) {
        latestVersion = release.version.description
        releaseNotes = release.notes
        releaseURL = release.url.absoluteString
    }
}

/// `~/Library/Caches/app.everydock.mac/update-check.json`. Missing or corrupt files mean "check now".
/// Homebrew removal and zap already clear this cache directory.
public struct UpdateCacheStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("app.everydock.mac", isDirectory: true)
            .appendingPathComponent("update-check.json", isDirectory: false)
    }

    public func load() -> UpdateCache {
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode(UpdateCache.self, from: data) else { return UpdateCache() }
        return cache
    }

    public func save(_ cache: UpdateCache) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cache).write(to: fileURL, options: .atomic)
    }
}

public enum UpdatePolicy {
    public static let checkInterval: TimeInterval = 86_400

    /// First run, 24 hours elapsed, or the clock moved backwards.
    public static func shouldCheck(now: TimeInterval, checkedAt: TimeInterval) -> Bool {
        checkedAt <= 0 || now < checkedAt || now - checkedAt >= checkInterval
    }

    /// A cached version newer than the current one and newer than any skipped version.
    public static func pendingUpdate(current: SemanticVersion, cache: UpdateCache, skippedVersion: String?) -> SemanticVersion? {
        guard let latest = cache.latestVersion.flatMap(SemanticVersion.init), latest > current else { return nil }
        if let skipped = skippedVersion.flatMap(SemanticVersion.init), latest <= skipped { return nil }
        return latest
    }
}

/// GitHub REST `releases/latest`. Drafts, prereleases, and non-version tags are treated as failures.
public enum LatestReleaseParser {
    private struct Response: Decodable {
        let tagName: String
        let body: String?
        let htmlURL: URL
        let draft: Bool?
        let prerelease: Bool?
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name", body, htmlURL = "html_url", draft, prerelease
        }
    }

    public static func parse(_ data: Data) -> LatestRelease? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.draft != true, response.prerelease != true,
              let version = SemanticVersion(response.tagName) else { return nil }
        return LatestRelease(version: version, notes: response.body ?? "", url: response.htmlURL)
    }
}

/// Offline, timeout, rate limit, and malformed responses all return nil; the next check is a day later.
public struct UpdateChecker: Sendable {
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/hungryZoo/everyDock/releases/latest")!
    public static let releasesURL = URL(string: "https://github.com/hungryZoo/everyDock/releases/latest")!
    public let apiURL: URL
    public let timeout: TimeInterval

    public init(apiURL: URL = Self.latestReleaseAPI, timeout: TimeInterval = 5) {
        self.apiURL = apiURL
        self.timeout = timeout
    }

    public func fetchLatest(userAgent: String) async -> LatestRelease? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return LatestReleaseParser.parse(data)
    }
}

/// Simplifies GitHub release Markdown for inline-only rendering: bold headings, `•` lists, no code fences.
public enum ReleaseNotesFormatter {
    public static func inlineMarkdown(_ body: String) -> String {
        var output: [String] = []
        var previousWasBlank = true
        for rawLine in body.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { continue }
            let converted: String
            if line.isEmpty {
                guard !previousWasBlank else { continue }
                converted = ""
            } else if let heading = headingText(line) {
                converted = "**\(heading)**"
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let indent = rawLine.prefix { $0 == " " }.count >= 2 ? "    " : ""
                converted = indent + "• " + line.dropFirst(2)
            } else {
                converted = line
            }
            output.append(converted)
            previousWasBlank = converted.isEmpty
        }
        while output.last?.isEmpty == true { output.removeLast() }
        return output.joined(separator: "\n")
    }

    private static func headingText(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}

/// Homebrew-owned apps update only through brew; everything else opens the release page.
public enum InstallMethod: Equatable, Sendable {
    case homebrew(brewPath: String)
    case manual

    /// Homebrew 7 refuses short names from untrusted taps, so commands always use the full name.
    public static let caskFullName = "hungryZoo/tap/everydock"

    public static func classify(appPath: String, homeDirectory: String, fileExists: (String) -> Bool) -> InstallMethod {
        let home = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        guard ["/Applications/everyDock.app", home + "/Applications/everyDock.app"].contains(appPath) else { return .manual }
        for prefix in ["/opt/homebrew", "/usr/local"] {
            let brew = prefix + "/bin/brew"
            if fileExists(prefix + "/Caskroom/everydock"), fileExists(brew) { return .homebrew(brewPath: brew) }
        }
        return .manual
    }
}

/// Terminal script for a Homebrew update. It waits for everyDock's normal quit, which restores the
/// macOS Dock, before brew replaces the bundle. `brew upgrade` keeps settings; the cask resets them
/// only for uninstall or reinstall.
public enum UpdateScript {
    public static func homebrew(brewPath: String, appPath: String, waitForPID pid: Int32) -> String {
        let brew = shellQuote(brewPath)
        let app = shellQuote(appPath)
        let cask = InstallMethod.caskFullName
        return """
        #!/bin/zsh
        # everyDock update (Homebrew)
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        echo \(shellQuote(L10n.text("everyDock update: brew update, brew upgrade --cask \(cask)")))
        echo
        \(brew) update
        if \(brew) upgrade --cask \(cask); then
          xattr -dr com.apple.quarantine \(app) 2>/dev/null
          open \(app)
          echo
          echo \(shellQuote(L10n.text("The update finished. You can close this window.")))
        else
          echo
          echo \(shellQuote(L10n.text("The update failed. Review the messages above.")))
        fi
        rm -f -- "$0"

        """
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
