import Foundation

/// Retains the pre-zoom frame because an AX size correction can reset an app's own zoom flag.
public struct WindowZoomState: Sendable, Equatable {
    public private(set) var normal: CGRect?
    public private(set) var fitted: CGRect?
    private var maximum: CGRect?
    public init() {}
    public mutating func observe(_ frame: CGRect, in areas: [WindowWorkArea]) {
        guard !areas.contains(where: { $0.adjusted(frame, fullScreen: false, minimized: false) != nil }) else { return }
        _ = destination(for: frame, in: areas)
    }

    public mutating func destination(for frame: CGRect, in areas: [WindowWorkArea]) -> CGRect? {
        guard frame.width >= 1, frame.height >= 1 else { return nil }
        if let fitted, Self.near(frame, fitted) { return nil } // Our own resize notification.
        guard let area = areas.max(by: { Self.overlap($0.visible, frame) < Self.overlap($1.visible, frame) }),
              area.visible.intersects(frame) else { reset(); return nil }
        guard let target = area.adjusted(frame, fullScreen: false, minimized: false) else {
            normal = frame; fitted = nil; maximum = nil // Manual resize/move or app-native restore.
            return nil
        }
        if fitted != nil, let maximum, Self.near(frame, maximum), let normal,
           area.visible.contains(normal) {
            self.fitted = nil; self.maximum = nil
            return normal
        }
        fitted = target; maximum = frame
        return target
    }
    public mutating func reset() { normal = nil; fitted = nil; maximum = nil }
    private static func overlap(_ a: CGRect, _ b: CGRect) -> Double {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
    private static func near(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }
}
