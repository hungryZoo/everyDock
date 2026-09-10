import AppKit
import QuartzCore

/// Display-synchronized progress only. AX calls consume the newest tick on a background worker.
@MainActor final class WindowRestoreClock: NSObject {
    private var link: CADisplayLink?
    private let continuation: AsyncStream<Double>.Continuation
    private let started = CACurrentMediaTime()
    private var timeout: Task<Void, Never>?
    static func frames(for frame: CGRect) -> AsyncStream<Double> {
        let (stream, continuation) = AsyncStream<Double>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let originY = NSScreen.screens.first?.frame.maxY ?? 0
        let screen = NSScreen.screens.max { a, b in
            func overlap(_ s: NSScreen) -> Double {
                let rect = CGRect(x: s.frame.minX, y: originY - s.frame.maxY, width: s.frame.width, height: s.frame.height).intersection(frame)
                return rect.isNull ? 0 : rect.width * rect.height
            }
            return overlap(a) < overlap(b)
        }
        guard let screen, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            continuation.yield(1); continuation.finish(); return stream
        }
        let clock = WindowRestoreClock(continuation: continuation)
        let link = screen.displayLink(target: clock, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        clock.link = link
        continuation.onTermination = { [weak clock] _ in Task { @MainActor in clock?.stop() } }
        link.add(to: .main, forMode: .common)
        clock.timeout = Task { @MainActor [weak clock] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            clock?.continuation.yield(1); clock?.stop()
        }
        return stream
    }
    private init(continuation: AsyncStream<Double>.Continuation) { self.continuation = continuation }
    @objc private func tick(_ link: CADisplayLink) {
        let progress = min(1, max(0, (link.targetTimestamp - started) / 0.18))
        continuation.yield(progress)
        if progress >= 1 { stop() }
    }
    private func stop() {
        link?.invalidate(); link = nil
        timeout?.cancel(); timeout = nil
        continuation.finish()
    }
}
