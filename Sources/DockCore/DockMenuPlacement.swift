import Foundation

public enum DockMenuPlacement {
    /// NSMenu's popup location is its top-left corner in screen coordinates.
    public static func topLeft(anchor: CGRect, menu: CGSize, edge: DockEdge, screen: CGRect) -> CGPoint {
        let x: Double, y: Double
        switch edge {
        case .bottom: x = anchor.midX - menu.width / 2; y = anchor.maxY + 6 + menu.height
        case .left: x = anchor.maxX + 6; y = anchor.midY + menu.height / 2
        case .right: x = anchor.minX - 6 - menu.width; y = anchor.midY + menu.height / 2
        }
        return CGPoint(x: min(max(screen.minX + 4, x), max(screen.minX + 4, screen.maxX - menu.width - 4)),
                       y: max(min(screen.maxY - 4, y), min(screen.maxY - 4, screen.minY + menu.height + 4)))
    }
}
