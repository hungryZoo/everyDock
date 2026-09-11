import AppKit
import ApplicationServices
import Combine
import DockCore
@preconcurrency import ScreenCaptureKit

@MainActor final class AppPermissions: ObservableObject {
    enum Status: Equatable {
        case unknown, allowed, denied
        var title: String {
            switch self { case .unknown: "Not Checked"; case .allowed: "Allowed"; case .denied: "Denied by macOS" }
        }
    }

    @Published private(set) var accessibility: Status = AXIsProcessTrusted() ? .allowed : .unknown
    @Published private(set) var capture: Status
    @Published private(set) var detail: String?
    @Published private(set) var accessibilityDetail: String?
    @Published private(set) var checking = false
    private var contentRequest: Task<SCShareableContent, Error>?
    private var contentCache: (SCShareableContent, Date)?
    private let capturePreflight: () -> Bool
    private let loadContent: () async throws -> SCShareableContent

    init(capturePreflight: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
         loadContent: @escaping () async throws -> SCShareableContent = {
             try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
         }) {
        self.capturePreflight = capturePreflight
        self.loadContent = loadContent
        capture = capturePreflight() ? .allowed : .unknown
    }

    /// Never requests access. A real denial stays blocked until the permission button is pressed.
    func refreshCaptureStatus() {
        if !capturePreflight() {
            if capture == .allowed { capture = .unknown }
            contentCache = nil
        } else if capture == .unknown {
            capture = .allowed
        }
    }

    var canCaptureWithoutPrompt: Bool {
        refreshCaptureStatus()
        return capture == .allowed
    }

    var needsGuidance: Bool {
        accessibility != .allowed || capture != .allowed || detail != nil
            || (accessibilityDetail != nil && accessibilityDetail != "noWindow" && accessibilityDetail != "unsupported")
    }

    func recordAccessibility(_ failure: WindowFailure?) {
        accessibilityDetail = failure.map { String(describing: $0) }
        if failure == .permissionDenied { accessibility = .denied }
        else if failure == nil || failure == .noWindow || failure == .unsupported { accessibility = .allowed }
    }

    /// Activation only reads permission hints; it must never trigger a system prompt.
    func refreshHints() {
        if AXIsProcessTrusted() { accessibility = .allowed }
        refreshCaptureStatus()
    }

    func shareableContent(retry: Bool = false, requestPermission: Bool = false) async throws -> SCShareableContent {
        if !requestPermission {
            guard canCaptureWithoutPrompt else {
                throw capture == .denied ? CaptureFailure.permissionDenied : CaptureFailure.permissionRequired
            }
        }
        if requestPermission { capture = .unknown }
        if retry { contentCache = nil }
        if capture == .denied { throw CaptureFailure.permissionDenied }
        if let (content, date) = contentCache, Date().timeIntervalSince(date) < 1 { return content }
        if let contentRequest { return try await contentRequest.value }
        let request = Task { try await loadContent() }
        contentRequest = request
        defer { contentRequest = nil }
        do {
            let content = try await request.value
            capture = .allowed
            detail = nil
            contentCache = (content, Date())
            return content
        } catch {
            let failure = CaptureFailure.classify(error)
            if failure == .permissionDenied { capture = .denied }
            else if case .unavailable(let message) = failure { detail = message }
            throw failure
        }
    }

    func invalidateContent() { contentCache = nil }

    func recordCaptureError(_ error: any Error) {
        let failure = CaptureFailure.classify(error)
        if failure == .permissionDenied { capture = .denied; contentCache = nil }
        else if case .unavailable(let message) = failure { detail = message }
    }

    func recheck(requestCapturePermission: Bool = false) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        if let process = NSWorkspace.shared.frontmostApplication,
           process.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let result = await WindowActions.list(pid: process.processIdentifier)
            recordAccessibility(result.failure)
        } else if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            let result = await WindowActions.list(pid: finder.processIdentifier)
            recordAccessibility(result.failure)
        }
        refreshCaptureStatus()
        guard requestCapturePermission else { return }
        do { _ = try await shareableContent(retry: true, requestPermission: true) }
        catch CaptureFailure.permissionDenied { detail = "macOS denied screen access for this app. If permission is already enabled, the registered app may have a different signature." }
        catch { detail = error.localizedDescription }
    }
}
