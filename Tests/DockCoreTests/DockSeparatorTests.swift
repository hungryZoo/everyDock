import Foundation
import Testing
@testable import DockCore

@Test func separatorsMigratePersistAndMoveAlongsidePins() throws {
    let legacy = Data(#"{"pinnedApps":[{"path":"/A.app","bundleIdentifier":"a"}]}"#.utf8)
    var prefs = try JSONDecoder().decode(DockPreferences.self, from: legacy)
    #expect(!prefs.pinnedApps[0].isSeparator)
    let line = PinnedApplication(separatorID: UUID())
    prefs.pinnedApps.append(line)
    prefs.pinnedApps.append(.init(path: "/B.app", bundleIdentifier: "b"))
    prefs.pinnedApps.swapAt(0, 1)
    let restored = try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(prefs))
    #expect(restored.pinnedApps.map(\.id) == [line.id, "/A.app", "/B.app"])
    #expect(restored.pinnedApps[0].separatorID == line.separatorID)
    prefs.pinnedApps.append(line)
    prefs.normalize()
    #expect(prefs.pinnedApps.count == 3)
}

@Test func separatorGeometryUsesFixedWidthAndTwoSectionBoundaries() {
    let plain = DockMetrics.length(iconSize: 48, appCount: 5)
    let grouped = DockMetrics.length(iconSize: 48, appCount: 5, customSeparators: 2, runningBoundary: true)
    #expect(grouped - plain == 2 * (DockMetrics.separatorSpace + DockMetrics.gap) + DockMetrics.separatorSpace)
    let smaller = DockMetrics.length(iconSize: 32, appCount: 5, customSeparators: 2, runningBoundary: true)
    #expect(grouped - smaller == Double(5 + DockMetrics.utilityCount) * 16)
}
