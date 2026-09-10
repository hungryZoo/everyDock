import Foundation
import Testing
@testable import EveryDock

@Test func appsLauncherIsNotTreatedAsRegularWindowApplication() {
    #expect(ApplicationCatalog.isLauncher(bundle: "com.apple.apps.launcher"))
    #expect(ApplicationCatalog.isLauncher(bundle: "com.apple.launchpad.launcher"))
    #expect(!ApplicationCatalog.isLauncher(bundle: "com.apple.finder"))
    #expect(!ApplicationCatalog.isLauncher(bundle: nil))
}
