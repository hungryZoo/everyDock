import Foundation

public enum WindowFrameAnimation {
    public static func frame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let t = min(1, max(0, progress))
        let eased = t * t * (3 - 2 * t)
        func blend(_ a: Double, _ b: Double) -> Double { a + (b - a) * eased }
        return CGRect(x: blend(from.minX, to.minX), y: blend(from.minY, to.minY),
                      width: blend(from.width, to.width), height: blend(from.height, to.height))
    }
}
