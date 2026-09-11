import Foundation
import Testing
@testable import DockCore

@Test func commandDragInsertionPreservesOrderAndAdjacentSlots() throws {
    let a = PinnedApplication(path: "/A.app", bundleIdentifier: "a")
    let b = PinnedApplication(path: "/B.app", bundleIdentifier: "b")
    let c = PinnedApplication(path: "/C.app", bundleIdentifier: "c")
    let line = PinnedApplication(separatorID: UUID())
    let pins = [a, line, b, c]
    #expect(DockReordering.inserting(a, into: pins, at: 4) == [line, b, c, a])
    #expect(DockReordering.inserting(c, into: pins, at: 0) == [c, a, line, b])
    #expect(DockReordering.inserting(line, into: pins, at: 4) == [a, b, c, line])
    #expect(DockReordering.inserting(b, into: pins, at: 2) == pins)
    #expect(DockReordering.inserting(b, into: pins, at: 3) == pins)
    var prefs = DockPreferences()
    prefs.pinnedApps = DockReordering.inserting(line, into: pins, at: 4)
    let restored = try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(prefs))
    #expect(restored.pinnedApps == [a, b, c, line])
}

@Test func commandDragPinsRunningAppWithoutDuplicates() {
    let a = PinnedApplication(path: "/A.app", bundleIdentifier: "a")
    let b = PinnedApplication(path: "/B.app", bundleIdentifier: "b")
    #expect(DockReordering.inserting(b, into: [a], at: 0) == [b, a])
    #expect(DockReordering.inserting(b, into: [], at: 99) == [b])
    #expect(DockReordering.inserting(b, into: [a], at: -1) == [b, a])
    let alias = PinnedApplication(path: "/Other/A.app", bundleIdentifier: "a")
    #expect(DockReordering.inserting(alias, into: [a, b], at: 2) == [b, a])
}
