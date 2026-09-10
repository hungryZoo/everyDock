import Testing
@testable import EveryDock

@Test func nativeMenuSelectionRejectsChangedCommands() {
    let original = NativeMenuStep(index: 3, title: "Command", identifier: "command", submenu: false)
    #expect(original.matches(original))
    #expect(!original.matches(.init(index: 4, title: "Command", identifier: "command", submenu: false)))
    #expect(!original.matches(.init(index: 3, title: "Other", identifier: "command", submenu: false)))
    #expect(!original.matches(.init(index: 3, title: "Command", identifier: "other", submenu: false)))
    #expect(!original.matches(.init(index: 3, title: "Command", identifier: "command", submenu: true)))
}
