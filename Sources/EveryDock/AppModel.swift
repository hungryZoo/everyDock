import AppKit
import Combine
import DockCore
import ServiceManagement
import UniformTypeIdentifiers
import ApplicationServices

struct DockApplication: Identifiable {
    let id: String
    let url: URL
    let name: String
    let icon: NSImage
    let bundleIdentifier: String?
    var isPinned: Bool
    var isRunning: Bool
    var isActive: Bool
    var isLaunching: Bool
    var isHidden: Bool
}

struct DisplayInfo: Identifiable {
    let id: String
    let name: String
    let size: String
}

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published var preferences: DockPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                UserDefaults.standard.set(data, forKey: Self.preferencesKey)
            }
            refreshApps()
            updateNativeDock()
            onLayoutChanged?()
        }
    }
    @Published private(set) var apps: [DockApplication] = []
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var accessibilityEnabled = AXIsProcessTrusted()
    @Published private(set) var nativeDockManaged = false
    @Published private(set) var nativeStyle = NativeDockStyle.read()
    @Published private(set) var screenCaptureEnabled = CGPreflightScreenCaptureAccess()
    var iconSize: Double { preferences.followNativeSize ? nativeStyle.size : preferences.iconSize }
    var magnification: Double { preferences.followNativeSize ? nativeStyle.magnification : preferences.magnification }
    var edgeInset: Double { preferences.followNativeSize ? 3 : preferences.inset }
    @Published var message: String?
    @Published var paused = false { didSet { updateNativeDock(); onLayoutChanged?() } }
    var onLayoutChanged: (() -> Void)?
    var showSettings: (() -> Void)?
    private var iconCache: [String: NSImage] = [:]
    private var nameCache: [String: String] = [:]
    private var pendingLaunches: [String: (url: URL, started: Date)] = [:]
    private var workspaceObservation: NSKeyValueObservation?
    private var applicationObservations: [pid_t: [NSKeyValueObservation]] = [:]
    private var observedApplications: [pid_t: NSRunningApplication] = [:]
    private var refreshTimer: Timer?
    private let nativeDock = NativeDockManager()
    let utilities = DockUtilities()
    private var clicksInProgress = Set<String>()
    private var lastExternalPID: pid_t?
    private var lastProcessSignature = ""
    private var lastListPreferences: DockPreferences?
    private static let preferencesKey = "everyDock.preferences.v1"

    override init() {
        var loaded: DockPreferences
        if let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
           let saved = try? JSONDecoder().decode(DockPreferences.self, from: data) {
            loaded = saved
        } else {
            loaded = DockPreferences()
            loaded.pinnedApps = Self.nativeDockApps()
            if loaded.pinnedApps.isEmpty {
                loaded.pinnedApps = ["com.apple.finder", "com.apple.Safari", "com.apple.mail", "com.apple.systempreferences"]
                    .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                    .map { PinnedApplication(path: $0.path, bundleIdentifier: Bundle(url: $0)?.bundleIdentifier) }
            }
        }
        loaded.normalize()
        preferences = loaded
        super.init()
        lastExternalPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        utilities.onChange = { [weak self] in self?.objectWillChange.send() }
        if let data = try? JSONEncoder().encode(loaded) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willLaunchApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification] {
            center.addObserver(self, selector: #selector(workspaceChanged), name: name, object: nil)
        }
        workspaceObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
            Task { @MainActor in self?.refreshApps() }
        }
        let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(reconcileApplications), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        refreshApps()
        refreshLoginStatus()
    }

    @objc private func workspaceChanged(_ notification: Notification) {
        if let process = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let url = process.bundleURL {
            let key = process.bundleIdentifier ?? url.path
            if notification.name == NSWorkspace.didActivateApplicationNotification,
               process.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                lastExternalPID = process.processIdentifier
            }
            if notification.name == NSWorkspace.willLaunchApplicationNotification && process.activationPolicy == .regular {
                pendingLaunches[key] = (url, Date())
            }
            if notification.name == NSWorkspace.didTerminateApplicationNotification { pendingLaunches.removeValue(forKey: key) }
        }
        refreshApps()
    }

    @objc private func reconcileApplications() {
        // Safety net for apps that change LSUIElement/activation policy after launching.
        refreshApps()
        let trusted = AXIsProcessTrusted()
        if accessibilityEnabled != trusted { accessibilityEnabled = trusted }
        let capture = CGPreflightScreenCaptureAccess()
        if screenCaptureEnabled != capture { screenCaptureEnabled = capture }
        let style = NativeDockStyle.read()
        if nativeStyle != style { nativeStyle = style; onLayoutChanged?() }
    }

    func refreshApps() {
        let all = NSWorkspace.shared.runningApplications
        observeApplications(all)
        pendingLaunches = pendingLaunches.filter { key, pending in
            Date().timeIntervalSince(pending.started) < 45 && !all.contains {
                ($0.bundleIdentifier ?? $0.bundleURL?.path) == key && $0.isFinishedLaunching
            }
        }
        let signature = all.map { "\($0.processIdentifier):\($0.activationPolicy.rawValue):\($0.isActive):\($0.isHidden):\($0.isFinishedLaunching)" }.joined(separator: ",")
            + pendingLaunches.keys.sorted().joined(separator: ",")
        if signature == lastProcessSignature && lastListPreferences == preferences { return }
        lastProcessSignature = signature
        lastListPreferences = preferences
        let running = all.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        var result: [DockApplication] = []
        var seen = Set<String>()
        for pinned in preferences.pinnedApps {
            let original = URL(fileURLWithPath: pinned.path)
            let url: URL
            if FileManager.default.fileExists(atPath: original.path) {
                url = original
            } else if let bundle = pinned.bundleIdentifier,
                      let relocated = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
                url = relocated
            } else {
                url = original // Keep unavailable pins visible so the user can remove them.
            }
            let process = running.first { $0.bundleURL == url || (pinned.bundleIdentifier != nil && $0.bundleIdentifier == pinned.bundleIdentifier) }
            let key = pinned.bundleIdentifier ?? url.path
            guard seen.insert(key).inserted else { continue }
            result.append(application(url: url, bundle: pinned.bundleIdentifier, pinned: true, process: process))
        }
        if preferences.showRunningApps {
            // Preserve order while focus changes so icons never jump under the pointer.
            let previousOrder = Dictionary(uniqueKeysWithValues: apps.enumerated().map { ($0.element.id, $0.offset) })
            let additional = running.filter { process in
                guard let url = process.bundleURL else { return false }
                return !seen.contains(process.bundleIdentifier ?? url.path)
            }.sorted { a, b in
                let aKey = a.bundleIdentifier ?? a.bundleURL?.path ?? ""
                let bKey = b.bundleIdentifier ?? b.bundleURL?.path ?? ""
                let ai = previousOrder[aKey] ?? Int.max
                let bi = previousOrder[bKey] ?? Int.max
                return ai == bi ? (a.localizedName ?? "") < (b.localizedName ?? "") : ai < bi
            }
            for process in additional {
                guard let url = process.bundleURL,
                      seen.insert(process.bundleIdentifier ?? url.path).inserted else { continue }
                result.append(application(url: url, bundle: process.bundleIdentifier, pinned: false, process: process))
            }
        }
        for (key, pending) in pendingLaunches.sorted(by: { $0.value.started < $1.value.started }) where seen.insert(key).inserted {
            result.append(application(url: pending.url, bundle: Bundle(url: pending.url)?.bundleIdentifier, pinned: false, process: nil))
        }
        let oldIDs = apps.map(\.id)
        let changed = apps.count != result.count || zip(apps, result).contains { a, b in
            a.id != b.id || a.isRunning != b.isRunning || a.isActive != b.isActive || a.isPinned != b.isPinned || a.isLaunching != b.isLaunching || a.isHidden != b.isHidden
        }
        if changed { apps = result }
        if oldIDs != result.map(\.id) { onLayoutChanged?() }
    }

    private func observeApplications(_ processes: [NSRunningApplication]) {
        let current = Set(processes.map(\.processIdentifier))
        for pid in Array(applicationObservations.keys) where !current.contains(pid) {
            applicationObservations.removeValue(forKey: pid)?.forEach { $0.invalidate() }
            observedApplications.removeValue(forKey: pid)
        }
        for process in processes where applicationObservations[process.processIdentifier] == nil {
            observedApplications[process.processIdentifier] = process
            let changed: @Sendable (NSRunningApplication, NSKeyValueObservedChange<Bool>) -> Void = { [weak self] _, _ in
                Task { @MainActor in self?.refreshApps() }
            }
            applicationObservations[process.processIdentifier] = [
                process.observe(\.isFinishedLaunching, changeHandler: changed),
                process.observe(\.isTerminated, changeHandler: changed),
                process.observe(\.activationPolicy) { [weak self] _, _ in Task { @MainActor in self?.refreshApps() } }
            ]
        }
    }

    private func application(url: URL, bundle: String?, pinned: Bool, process: NSRunningApplication?) -> DockApplication {
        let icon = iconCache[url.path] ?? NSWorkspace.shared.icon(forFile: url.path)
        iconCache[url.path] = icon
        let name = nameCache[url.path] ?? process?.localizedName ?? FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        nameCache[url.path] = name
        return DockApplication(id: bundle ?? url.path, url: url, name: name, icon: icon,
                               bundleIdentifier: bundle, isPinned: pinned,
                               isRunning: process != nil, isActive: process?.isActive == true && process?.isHidden == false,
                               isLaunching: pendingLaunches[bundle ?? url.path] != nil || (process != nil && process?.isFinishedLaunching == false),
                               isHidden: process?.isHidden ?? false)
    }

    func launch(_ app: DockApplication, toggle: Bool = true) {
        if let process = NSWorkspace.shared.runningApplications.first(where: {
            !$0.isTerminated && ($0.bundleURL == app.url || (app.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier))
        }) {
            guard clicksInProgress.insert(app.id).inserted else { return }
            let ourAppIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            let active = (process.isActive || (ourAppIsFrontmost && lastExternalPID == process.processIdentifier)) && !process.isHidden
            let shouldMinimize = toggle && preferences.clickToMinimize
            Task { @MainActor in
                let result = await WindowActions.toggle(pid: process.processIdentifier, active: active, minimize: shouldMinimize)
                defer { clicksInProgress.remove(app.id); refreshApps() }
                switch result {
                case .minimized: return
                case .unavailable where active && shouldMinimize:
                    report("창 최소화에는 손쉬운 사용 권한이 필요합니다. 설정에서 권한을 허용해 주세요. 이 앱이 최소화를 지원하지 않는 경우에도 창을 숨기지 않고 유지합니다.")
                case .restored, .activate, .unavailable:
                    process.unhide()
                    process.activate(options: [.activateAllWindows])
                    // Reopen is needed when all windows were closed, not just hidden/minimized.
                    if result != .restored { openApplication(app) }
                }
            }
            return
        }
        guard !app.isLaunching else { return }
        pendingLaunches[app.id] = (app.url, Date())
        refreshApps() // Begin the bounce before Launch Services responds.
        openApplication(app)
    }

    private func openApplication(_ app: DockApplication) {
        guard FileManager.default.fileExists(atPath: app.url.path) else {
            pendingLaunches.removeValue(forKey: app.id)
            refreshApps()
            report("\(app.name)을(를) 찾을 수 없습니다. 고정을 해제한 뒤 앱을 다시 추가해 주세요.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { [weak self] _, error in
            let detail = error?.localizedDescription
            Task { @MainActor in
                if let detail {
                    self?.pendingLaunches.removeValue(forKey: app.id)
                    self?.report("앱을 열 수 없습니다: \(detail)")
                }
                self?.refreshApps()
            }
        }
    }

    func updateNativeDock() {
        let hasDock = NSScreen.screens.contains { !preferences.hiddenDisplayIDs.contains(Self.displayID($0)) }
        do {
            try nativeDock.setManaging(preferences.manageNativeDock && !paused && hasDock)
            nativeDockManaged = nativeDock.isManaging
        } catch {
            message = "기본 Dock을 관리하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func requestScreenCapture() {
        _ = CGRequestScreenCaptureAccess()
        screenCaptureEnabled = CGPreflightScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func stop() {
        utilities.stop()
        refreshTimer?.invalidate()
        workspaceObservation?.invalidate()
        applicationObservations.values.flatMap { $0 }.forEach { $0.invalidate() }
        applicationObservations.removeAll()
        observedApplications.removeAll()
        try? nativeDock.setManaging(false)
    }

    func togglePin(_ app: DockApplication) {
        if app.isPinned {
            preferences.pinnedApps.removeAll { $0.path == app.url.path || (app.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier) }
        } else { addApps([app.url]) }
    }

    func addApps(_ urls: [URL]) {
        var updated = preferences
        for url in urls where url.pathExtension.lowercased() == "app" {
            guard let bundle = Bundle(url: url), bundle.executableURL != nil,
                  bundle.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            updated.pinnedApps.append(.init(path: url.path, bundleIdentifier: bundle.bundleIdentifier))
        }
        updated.normalize()
        preferences = updated
    }

    func chooseApps() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Dock에 고정할 앱 선택"
        panel.prompt = "추가"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK { addApps(panel.urls) }
    }

    func movePin(_ app: DockApplication, offset: Int) {
        guard let index = preferences.pinnedApps.firstIndex(where: {
            $0.path == app.url.path || (app.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)
        }) else { return }
        let destination = index + offset
        guard preferences.pinnedApps.indices.contains(destination) else { return }
        preferences.pinnedApps.swapAt(index, destination)
    }

    func quit(_ app: DockApplication) {
        NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL == app.url || (app.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier)
        }.forEach { _ = $0.terminate() }
    }

    func updateDisplays() {
        displays = NSScreen.screens.map {
            DisplayInfo(id: Self.displayID($0), name: $0.localizedName,
                        size: "\(Int($0.frame.width)) × \(Int($0.frame.height)) pt")
        }
    }

    static func displayID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return screen.localizedName
        }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return number.stringValue
    }

    func importNativeDock() {
        let imported = Self.nativeDockApps()
        guard !imported.isEmpty else {
            message = "기본 Dock의 고정 앱을 읽지 못했습니다. ‘앱 추가’로 직접 선택할 수 있습니다."
            return
        }
        addApps(imported.map { URL(fileURLWithPath: $0.path) })
    }

    private static func nativeDockApps() -> [PinnedApplication] {
        // Read-only, best-effort import of Apple's undocumented preferences format.
        let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")
        let entries = domain?["persistent-apps"] as? [[String: Any]] ?? []
        var urls = [URL]()
        if let finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") { urls.append(finder) }
        for entry in entries {
            guard let tile = entry["tile-data"] as? [String: Any],
                  let file = tile["file-data"] as? [String: Any],
                  let path = file["_CFURLString"] as? String else { continue }
            let url = path.hasPrefix("file:") ? URL(string: path) : URL(fileURLWithPath: path)
            if let url, url.pathExtension == "app", FileManager.default.fileExists(atPath: url.path) {
                urls.append(url)
            }
        }
        // Finder alone does not indicate a successful import.
        guard urls.count > 1 else { return [] }
        return urls.map { .init(path: $0.path, bundleIdentifier: Bundle(url: $0)?.bundleIdentifier) }
    }

    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { message = "로그인 항목을 변경하지 못했습니다: \(error.localizedDescription)" }
        refreshLoginStatus()
    }

    func openSystemDockSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
    }

    private func report(_ text: String) {
        message = text
        showSettings?()
    }
}
