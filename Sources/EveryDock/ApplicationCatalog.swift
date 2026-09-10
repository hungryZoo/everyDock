import Foundation

/// Apps.app is a Dock launcher, not a regular app with windows to activate/minimize.
enum ApplicationCatalog {
    static func isLauncher(bundle: String?) -> Bool { bundle == "com.apple.apps.launcher" || bundle == "com.apple.launchpad.launcher" }
}
