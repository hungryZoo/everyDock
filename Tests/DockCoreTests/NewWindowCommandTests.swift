import Testing
@testable import DockCore

@Test func newWindowCommandRequiresWindowTitleAndPrefersCommandN() {
    // Titles observed on macOS 26 with Korean and English menus.
    #expect(NewWindowCommand.rank(title: "새로운 Finder 윈도우", character: "N", modifiers: 0, enabled: true) == 0)
    #expect(NewWindowCommand.rank(title: "새 창", character: "N", modifiers: 0, enabled: true) == 0)
    #expect(NewWindowCommand.rank(title: "New Window", character: "n", modifiers: nil, enabled: true) == 0)
    #expect(NewWindowCommand.rank(title: "New Window", character: "N", modifiers: 1, enabled: true) == 1)
    #expect(NewWindowCommand.rank(title: "새로운 이벤트 또는 미리 알림", character: "N", modifiers: 0, enabled: true) == nil)
    #expect(NewWindowCommand.rank(title: "New Text File", character: "N", modifiers: 0, enabled: true) == nil)
    #expect(NewWindowCommand.rank(title: "새 채팅", character: "N", modifiers: 0, enabled: true) == nil)
    #expect(NewWindowCommand.rank(title: "New Window", character: "N", modifiers: 0, enabled: false) == nil)
    #expect(NewWindowCommand.rank(title: "New Window", character: "N", modifiers: 2, enabled: true) == nil)
    #expect(NewWindowCommand.rank(title: "New Tab", character: "T", modifiers: 0, enabled: true) == nil)
}
