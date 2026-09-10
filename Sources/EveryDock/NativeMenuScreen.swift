import Foundation

enum NativeMenuScreen {
    // A hidden Dock's icons can sit just outside the screen; choose the nearest screen.
    static func matches(point: CGPoint, target: CGRect, screens: [CGRect]) -> Bool {
        func distance(_ frame: CGRect) -> Double {
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            return dx * dx + dy * dy
        }
        guard point.x.isFinite, point.y.isFinite, screens.contains(target),
              let nearest = screens.min(by: { distance($0) < distance($1) }) else { return false }
        return nearest == target
    }
}
