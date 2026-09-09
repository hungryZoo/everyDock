import Foundation

public struct PreviewLayout: Sendable {
    public let columns: Int
    public let width: Double
    public let gridHeight: Double
    public init(count: Int) {
        columns = count == 1 ? 1 : 2
        width = count == 0 ? 300 : Double(columns) * 190 + Double(columns - 1) * 12 + 32
        gridHeight = min(340, Double((max(0, count) + columns - 1) / columns) * 160)
    }
}
