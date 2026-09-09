import Foundation
import Testing
@testable import EveryDock

@Test func appsLauncherIsNotTreatedAsRegularWindowApplication() {
    #expect(ApplicationCatalog.isLauncher(bundle: "com.apple.apps.launcher"))
    #expect(ApplicationCatalog.isLauncher(bundle: "com.apple.launchpad.launcher"))
    #expect(!ApplicationCatalog.isLauncher(bundle: "com.apple.finder"))
    #expect(!ApplicationCatalog.isLauncher(bundle: nil))
}
@Test func catalogIncludesNestedUtilitiesButNotEmbeddedHelperApps() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("everyDock-catalog-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    for path in ["One.app/Contents/Helper.app", "Utilities/Two.app", ".Hidden.app"] {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
    }
    let urls = ApplicationCatalog.urls(roots: [root, root])
    #expect(Set(urls.map(\.lastPathComponent)) == ["One.app", "Two.app"])
    #expect(urls.count == 2)
}
