import AppKit

struct NativeDockStyle: Equatable {
    var size: Double
    var magnification: Double
    static func read() -> Self {
        let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.dock") ?? [:]
        let size = min(96, max(16, (domain["tilesize"] as? NSNumber)?.doubleValue ?? 48))
        let large = min(128, max(size, (domain["largesize"] as? NSNumber)?.doubleValue ?? 96))
        return Self(size: size, magnification: (domain["magnification"] as? Bool ?? false) ? large / size : 1)
    }
}
