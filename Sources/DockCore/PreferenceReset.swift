import Foundation

public enum PreferenceReset {
    public static func clear(domain: String, defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }
}
