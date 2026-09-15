import Foundation
import DockCore

/// Serializes preference IO away from pointer tracking and animation frames.
actor NativeDockPinSync {
    enum Failure: Error { case unsupportedPreferences, writeFailed }
    private let preferenceDomain: String
    init(preferenceDomain: String = "com.apple.dock") { self.preferenceDomain = preferenceDomain }
    /// nil means no readable saved list; an empty array is a valid unpin-all operation.
    func read() throws -> [PinnedApplication]? {
        let domain = preferenceDomain as CFString
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { throw Failure.writeFailed }
        guard let value = CFPreferencesCopyValue("persistent-apps" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
        guard let entries = value as? [[String: Any]] else { throw Failure.unsupportedPreferences }
        return entries.compactMap { entry in
            guard let path = NativeDockPins.path(of: entry) else { return nil }
            let tile = entry["tile-data"] as? [String: Any]
            return PinnedApplication(path: path, bundleIdentifier: tile?["bundle-identifier"] as? String ?? Bundle(path: path)?.bundleIdentifier)
        }
    }
    func apply(pins: [PinnedApplication], removing: Set<String>) throws -> Bool {
        let domain = preferenceDomain as CFString
        let key = "persistent-apps" as CFString
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { throw Failure.writeFailed }
        let value = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard value == nil || value is [[String: Any]] else { throw Failure.unsupportedPreferences }
        let current = value as? [[String: Any]] ?? []
        let available = pins.filter { $0.isSeparator || FileManager.default.fileExists(atPath: $0.path) }
        let updated = NativeDockPins.reordered(current, pins: available, removing: removing)
        guard !(current as NSArray).isEqual(to: updated) else { return false }
        CFPreferencesSetValue(key, updated as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let readback = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [[String: Any]],
              (updated as NSArray).isEqual(to: readback) else { throw Failure.writeFailed }
        return true
    }
}
