import Foundation

public enum DockReordering {
    /// Slot is measured before removing the source, so adjacent slots are no-ops.
    public static func inserting(_ item: PinnedApplication, into pins: [PinnedApplication], at slot: Int) -> [PinnedApplication] {
        let slot = min(pins.count, max(0, slot))
        let source = pins.firstIndex { $0.id == item.id || (item.bundleIdentifier != nil && $0.bundleIdentifier == item.bundleIdentifier) }
        var result = pins
        let moved = source.map { result.remove(at: $0) } ?? item
        let destination = slot - ((source.map { $0 < slot } ?? false) ? 1 : 0)
        result.insert(moved, at: destination)
        return result
    }
}
