import AppKit
import DockCore
import Darwin

@MainActor
final class NativeDockManager {
    private static let domain = "com.apple.dock" as CFString
    private static let applied: [String: DockPreferenceValue] = [
        "autohide": .boolean(true),
        "autohide-delay": .number(3600),
        "autohide-time-modifier": .number(0),
        "mineffect": .string("genie")
    ]
    private var watchdog: Process?
    private(set) var isManaging = false
    private let journal: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("everyDock", isDirectory: true)
        journal = folder.appendingPathComponent("native-dock-recovery-\(UUID().uuidString).json")
    }

    func setManaging(_ enabled: Bool) throws {
        guard enabled != isManaging else { return }
        try Self.withRecoveryLock(folder: journal.deletingLastPathComponent()) {
        if enabled {
            // Recover an interrupted previous session before capturing the user's settings.
            for old in try FileManager.default.contentsOfDirectory(at: journal.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                where old.lastPathComponent.hasPrefix("native-dock-recovery") && old.pathExtension == "json" {
                try Self.restoreUnlocked(from: old)
            }
            let original = Self.readValues()
            let snapshot = NativeDockSnapshot(original: original, applied: Self.applied)
            try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: journal, options: .atomic)
            guard let executable = Bundle.main.executableURL else { throw CocoaError(.fileNoSuchFile) }
            let child = Process()
            child.executableURL = executable
            child.arguments = ["--dock-watchdog", String(ProcessInfo.processInfo.processIdentifier), journal.path]
            child.standardOutput = FileHandle.nullDevice
            child.standardError = FileHandle.nullDevice
            try child.run() // Do not change the Dock if recovery cannot be started.
            watchdog = child
            Self.write(Self.applied)
            isManaging = true
            Self.restartDock()
        } else {
            try Self.restoreUnlocked(from: journal)
            isManaging = false
            watchdog?.terminate()
            watchdog = nil
        }
        }
    }

    static func runWatchdog(parent: pid_t, journal: URL) {
        // kqueue tracks process exit, including SIGKILL, without periodic polling or PID reuse.
        let queue = kqueue()
        if queue >= 0 {
            var change = kevent(ident: UInt(parent), filter: Int16(EVFILT_PROC),
                                flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT),
                                fflags: UInt32(NOTE_EXIT), data: 0, udata: nil)
            var result = kevent()
            if kevent(queue, &change, 1, nil, 0, nil) == 0 && kill(parent, 0) == 0 {
                _ = kevent(queue, nil, 0, &result, 1, nil)
            }
            close(queue)
        } else {
            while kill(parent, 0) == 0 { Thread.sleep(forTimeInterval: 0.5) }
        }
        try? restore(from: journal)
    }

    private static func readValues() -> [String: DockPreferenceValue] {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return applied.mapValues { _ in .absent }.merging(Dictionary(uniqueKeysWithValues: applied.keys.map { key in
            guard let value = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
                return (key, .absent)
            }
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return (key, .boolean((value as! NSNumber).boolValue)) }
            if let text = value as? String { return (key, .string(text)) }
            return (key, .number((value as? NSNumber)?.doubleValue ?? 0))
        })) { _, new in new }
    }

    private static func write(_ values: [String: DockPreferenceValue]) {
        for (key, value) in values {
            let property: CFPropertyList?
            switch value {
            case .absent: property = nil
            case .boolean(let value): property = value as CFBoolean
            case .number(let value): property = value as CFNumber
            case .string(let value): property = value as CFString
            }
            CFPreferencesSetValue(key as CFString, property, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func restore(from journal: URL) throws {
        try withRecoveryLock(folder: journal.deletingLastPathComponent()) { try restoreUnlocked(from: journal) }
    }

    private static func withRecoveryLock(folder: URL, body: () throws -> Void) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(folder.appendingPathComponent("recovery.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        defer { flock(descriptor, LOCK_UN) }
        try body()
    }

    private static func restoreUnlocked(from journal: URL) throws {
        guard FileManager.default.fileExists(atPath: journal.path) else { return }
        let snapshot = try JSONDecoder().decode(NativeDockSnapshot.self, from: Data(contentsOf: journal))
        let restore = snapshot.restoration(current: readValues())
        write(restore)
        try FileManager.default.removeItem(at: journal)
        if !restore.isEmpty { restartDock() }
    }

    private static func restartDock() {
        // Dock also owns Mission Control; terminate only for preference changes, never disable it.
        for dock in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock") {
            kill(dock.processIdentifier, SIGTERM)
        }
    }
}
