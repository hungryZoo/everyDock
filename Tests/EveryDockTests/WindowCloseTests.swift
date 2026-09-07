import Testing
@testable import EveryDock

private actor CloseRecorder {
    var attempted: [Int] = []
    func record(_ id: Int) { attempted.append(id) }
}
@Test func closeAllStopsAtSaveConfirmation() async {
    let recorder = CloseRecorder()
    let result = await WindowCloseSequence.perform(snapshot: [1, 2, 3]) { id in
        await recorder.record(id)
        return id == 2 ? .awaitingApplication : .closed
    }
    #expect(await recorder.attempted == [1, 2])
    guard case .awaitingApplication = result else { Issue.record("Save confirmation must stop closing"); return }
}
@Test func closeAllSkipsAlreadyClosedButStopsAtErrors() async {
    let recorder = CloseRecorder()
    let result = await WindowCloseSequence.perform(snapshot: [1, 2, 3]) { id in
        await recorder.record(id)
        return id == 1 ? .failed(.noWindow) : .failed(.unsupported)
    }
    #expect(await recorder.attempted == [1, 2])
    guard case .failed(.unsupported) = result else { Issue.record("Must report the first close error"); return }
}
@Test func closeAllCompletesOnlyItsInitialSnapshot() async {
    let recorder = CloseRecorder()
    let result = await WindowCloseSequence.perform(snapshot: [1, 2, 3]) { id in
        await recorder.record(id)
        return .closed
    }
    #expect(await recorder.attempted == [1, 2, 3])
    guard case .closed = result else { Issue.record("All snapshot windows closed"); return }
}
