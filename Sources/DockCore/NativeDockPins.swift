import Foundation

/// Edit only application tiles. Keep existing metadata and non-application entries intact.
public enum NativeDockPins {
    /// Native apps are authoritative; local separators retain their numbered slots.
    /// Finder is not stored in persistent-apps, so retain its existing local slot too.
    public static func importing(_ native: [PinnedApplication], into local: [PinnedApplication]) -> [PinnedApplication] {
        var seen = Set<String>()
        let apps = native.filter {
            !$0.isSeparator && $0.bundleIdentifier != "com.apple.finder" && seen.insert($0.path).inserted
        }
        var result: [PinnedApplication] = []
        var index = 0
        for pin in local {
            if pin.isSeparator || pin.bundleIdentifier == "com.apple.finder" {
                result.append(pin)
            } else if index < apps.count {
                result.append(apps[index])
                index += 1
            }
        }
        result.append(contentsOf: apps.dropFirst(index))
        return result
    }

    public static func path(of entry: [String: Any]) -> String? {
        guard entry["tile-type"] as? String == "file-tile",
              let tile = entry["tile-data"] as? [String: Any],
              let file = tile["file-data"] as? [String: Any],
              let raw = file["_CFURLString"] as? String else { return nil }
        let url = raw.hasPrefix("file:") ? URL(string: raw) : URL(fileURLWithPath: raw)
        guard let url, url.isFileURL, url.pathExtension.lowercased() == "app" else { return nil }
        return url.standardizedFileURL.path
    }

    public static func reordered(_ current: [[String: Any]], pins: [PinnedApplication], removing: Set<String> = []) -> [[String: Any]] {
        let desired = pins.filter { !$0.isSeparator && $0.bundleIdentifier != "com.apple.finder" && URL(fileURLWithPath: $0.path).pathExtension.lowercased() == "app" }
        let existing = current.filter { entry in path(of: entry).map { !removing.contains($0) } ?? true }
        var consumed = Set<Int>()
        var ordered: [[String: Any]] = []
        var seen = Set<String>()
        for pin in desired {
            let url = URL(fileURLWithPath: pin.path).standardizedFileURL
            guard seen.insert(url.path).inserted else { continue }
            if let index = existing.indices.first(where: { index in
                guard !consumed.contains(index), path(of: existing[index]) != nil else { return false }
                let tile = existing[index]["tile-data"] as? [String: Any]
                return path(of: existing[index]) == url.path || (pin.bundleIdentifier != nil && tile?["bundle-identifier"] as? String == pin.bundleIdentifier)
            }) {
                consumed.insert(index)
                ordered.append(existing[index])
            } else {
                var tile: [String: Any] = ["file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15],
                                           "file-label": url.deletingPathExtension().lastPathComponent]
                if let bundle = pin.bundleIdentifier { tile["bundle-identifier"] = bundle }
                ordered.append(["GUID": UInt32.random(in: 1...UInt32.max), "tile-type": "file-tile", "tile-data": tile])
            }
        }
        // Native-only apps remain pinned, after the shared apps, in their original relative order.
        for index in existing.indices where !consumed.contains(index) && path(of: existing[index]) != nil {
            ordered.append(existing[index])
        }
        var result: [[String: Any]] = [], index = 0
        for entry in existing {
            if path(of: entry) == nil { result.append(entry) }
            else if index < ordered.count { result.append(ordered[index]); index += 1 }
        }
        result.append(contentsOf: ordered.dropFirst(index))
        return result
    }
}
