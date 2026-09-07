import Foundation

/// AX determines the rows. Capture metadata only supplies an image, never another row.
public enum WindowMatching {
    public struct Candidate: Sendable {
        public let title: String
        public let frame: CGRect
        public init(title: String, frame: CGRect) { self.title = title; self.frame = frame }
    }
    public static func match(windows: [Candidate], captures: [Candidate]) -> [Int: Int] {
        var edges: [(window: Int, capture: Int, score: Double)] = []
        for (i, window) in windows.enumerated() {
            for (j, capture) in captures.enumerated() {
                let deltas = [abs(window.frame.minX - capture.frame.minX), abs(window.frame.minY - capture.frame.minY),
                              abs(window.frame.width - capture.frame.width), abs(window.frame.height - capture.frame.height)]
                guard window.frame.width > 0, window.frame.height > 0, deltas.allSatisfy({ $0 <= 8 }) else { continue }
                edges.append((i, j, deltas.reduce(0, +) + (window.title == capture.title ? 0 : 1)))
            }
        }
        edges.sort { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.window != b.window { return a.window < b.window }
            return a.capture < b.capture
        }
        var result: [Int: Int] = [:], used = Set<Int>()
        for edge in edges where result[edge.window] == nil && !used.contains(edge.capture) {
            result[edge.window] = edge.capture
            used.insert(edge.capture)
        }
        return result
    }
}
