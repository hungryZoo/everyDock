import Foundation
import QuartzCore

/// Opt-in callback timing for local profiling; never records app names or screen content.
@MainActor final class FrameTrace {
    private let enabled = ProcessInfo.processInfo.environment["EVERYDOCK_TRACE_FRAMES"] == "1"
    private var samples: [Double] = []
    private var costs: [Double] = []
    private var previous: Double?
    private var expected = 1.0 / 60
    func begin(timestamp: Double, interval: Double) -> Double? {
        guard enabled else { return nil }
        expected = interval
        if let previous { samples.append(timestamp - previous) }
        previous = timestamp
        return CACurrentMediaTime()
    }
    func end(start: Double?) {
        if let start { costs.append(CACurrentMediaTime() - start) }
    }
    func flush() {
        guard enabled, !costs.isEmpty else { return }
        let sorted = costs.sorted()
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] * 1000
        let gaps = samples.filter { $0 > expected * 1.5 }.count
        let line = String(format: "everyDock frames=%d expectedHz=%.0f callbackGapOver1.5x=%d renderP95ms=%.3f\n", costs.count, 1 / expected, gaps, p95)
        FileHandle.standardError.write(Data(line.utf8))
        samples.removeAll(keepingCapacity: true)
        costs.removeAll(keepingCapacity: true)
        previous = nil
    }
}
