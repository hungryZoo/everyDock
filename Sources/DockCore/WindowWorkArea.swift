import Foundation

/// All coordinates use Accessibility's top-left screen origin, including negative displays.
public struct WindowWorkArea: Equatable, Sendable {
    public let visible: CGRect
    public let usable: CGRect
    public let edge: DockEdge
    public init(visible: CGRect, dockBoundary: Double, edge: DockEdge) {
        self.visible = visible
        self.edge = edge
        switch edge {
        case .bottom:
            usable = CGRect(x: visible.minX, y: visible.minY, width: visible.width,
                            height: max(0, min(visible.maxY, dockBoundary) - visible.minY))
        case .left:
            let x = max(visible.minX, dockBoundary)
            usable = CGRect(x: x, y: visible.minY, width: max(0, visible.maxX - x), height: visible.height)
        case .right:
            usable = CGRect(x: visible.minX, y: visible.minY,
                            width: max(0, min(visible.maxX, dockBoundary) - visible.minX), height: visible.height)
        }
    }
    public func adjusted(_ frame: CGRect, fullScreen: Bool, minimized: Bool) -> CGRect? {
        guard !fullScreen, !minimized, usable.width >= 200, usable.height >= 150 else { return nil }
        let tolerance = 12.0
        // Only screen-filling windows. Ordinary user sizes and the reverse zoom remain intact.
        switch edge {
        case .bottom:
            guard abs(frame.minY - visible.minY) <= tolerance, abs(frame.maxY - visible.maxY) <= tolerance,
                  frame.maxY > usable.maxY + 1 else { return nil }
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: usable.maxY - frame.minY)
        case .left, .right:
            guard abs(frame.minX - visible.minX) <= tolerance, abs(frame.maxX - visible.maxX) <= tolerance else { return nil }
            if edge == .left {
                guard frame.minX < usable.minX - 1 else { return nil }
                return CGRect(x: usable.minX, y: frame.minY, width: frame.maxX - usable.minX, height: frame.height)
            }
            guard frame.maxX > usable.maxX + 1 else { return nil }
            return CGRect(x: frame.minX, y: frame.minY, width: usable.maxX - frame.minX, height: frame.height)
        }
    }
}
