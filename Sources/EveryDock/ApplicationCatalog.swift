import Foundation

/// Apps.app is a Dock launcher, not a regular app with windows to activate/minimize.
enum ApplicationCatalog {
    static func isLauncher(bundle: String?) -> Bool { bundle == "com.apple.apps.launcher" || bundle == "com.apple.launchpad.launcher" }
    static func urls(roots: [URL] = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"),
                                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]) -> [URL] {
        var result: [URL] = [], seen = Set<String>()
        for root in roots {
            guard let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in items {
                guard url.pathExtension.lowercased() == "app" else { continue }
                items.skipDescendants()
                let bundle = Bundle(url: url)?.bundleIdentifier
                guard !isLauncher(bundle: bundle), seen.insert(url.resolvingSymlinksInPath().path).inserted else { continue }
                result.append(url)
            }
        }
        return result
    }
}
