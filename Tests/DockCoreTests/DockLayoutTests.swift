import Foundation
import CoreGraphics
import Testing
@testable import DockCore

@Test func positionsOnDisplaysWithNegativeOrigins() {
    let screen = CGRect(x: -1920, y: -400, width: 1920, height: 1080)
    for edge in DockEdge.allCases {
        let frame = DockLayout.frame(in: screen, edge: edge, iconSize: 48, itemCount: 8, inset: 10)
        #expect(screen.contains(frame))
        if edge == .bottom { #expect(frame.minY == -390) }
        if edge == .left { #expect(frame.minX == -1910) }
        if edge == .right { #expect(frame.maxX == -10) }
    }
}

@Test func overflowingDockFitsScreen() {
    let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
    for edge in DockEdge.allCases {
        let frame = DockLayout.frame(in: screen, edge: edge, iconSize: 72, itemCount: 100, inset: 40)
        #expect(screen.contains(frame))
        #expect(frame.width <= 720)
        #expect(frame.height <= 520)
    }
}

@Test func bottomUsesUsableAreaAboveNativeDock() {
    let usable = CGRect(x: 0, y: 90, width: 1440, height: 785)
    let frame = DockLayout.frame(in: usable, edge: .bottom, iconSize: 48, itemCount: 0, inset: 10)
    #expect(frame.minY == 100)
    #expect(frame.midX == usable.midX)
    #expect(frame.width > 0)
}

@Test func preferencesRoundTripAndNormalize() throws {
    var preferences = DockPreferences()
    preferences.iconSize = 900
    preferences.inset = -5
    preferences.hiddenDisplayIDs = ["external-display"]
    preferences.pinnedApps = [
        .init(path: "/Applications/A.app", bundleIdentifier: "a"),
        .init(path: "/Other/A.app", bundleIdentifier: "a"),
        .init(path: "/Applications/B.app", bundleIdentifier: "b")
    ]
    preferences.normalize()
    #expect(preferences.iconSize == 72)
    #expect(preferences.inset == 0)
    #expect(preferences.pinnedApps.count == 2)
    let restored = try JSONDecoder().decode(DockPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored == preferences)
}
