import Foundation

public enum FileOrdering {
    public static func precedes(date: Date, name: String, otherDate: Date, otherName: String) -> Bool {
        if date != otherDate { return date > otherDate }
        let order = name.localizedStandardCompare(otherName)
        return order == .orderedSame ? name < otherName : order == .orderedAscending
    }
}
