import AppKit
import ApplicationServices
import Combine
import DockCore
@preconcurrency import ScreenCaptureKit

@MainActor final class AppPermissions: ObservableObject {
        enum Status: Equatable {
        case unknown, allowed, denied
        var title: String {
            switch self { case .unknown: "확인 전"; case .allowed: "사용 가능"; case .denied: "macOS에서 거부됨" }
        }
    }

    @Published private(set) var accessibility: Status = AXIsProcessTrusted() ? .allowed : .unknown
    @Published private(set) var capture: Status = CGPreflightScreenCaptureAccess() ? .allowed : .unknown
    @Published private(set) var detail: String?
    @Published private(set) var accessibilityDetail: String?
    @Published private(set) var checking = false
    private var contentRequest: Task<SCShareableContent, Error>?
    private var contentCache: (SCShareableContent, Date)?

    func recordAccessibility(_ failure: WindowFailure?) {
        accessibilityDetail = failure.map { String(describing: $0) }
        if failure == .permissionDenied { accessibility = .denied }
        else if failure == nil || failure == .noWindow || failure == .unsupported { accessibility = .allowed }
    }

    /// Preflight is a hint, never a veto over an actual successful OS operation.
    func refreshHints() {
        if AXIsProcessTrusted() { accessibility = .allowed }
        if CGPreflightScreenCaptureAccess() { capture = .allowed }
    }

    func shareableContent(retry: Bool = false) async throws -> SCShareableContent {
        if retry { contentCache = nil; capture = .unknown }
        if capture == .denied { throw CaptureFailure.permissionDenied }
        if let (content, date) = contentCache, Date().timeIntervalSince(date) < 1 { return content }
        if let contentRequest { return try await contentRequest.value }
        let request = Task { try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) }
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

    func recordCaptureError(_ error: any Error) {
        let failure = CaptureFailure.classify(error)
        if failure == .permissionDenied { capture = .denied; contentCache = nil }
        else if case .unavailable(let message) = failure { detail = message }
    }

    func recheck() async {
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
        do { _ = try await shareableContent(retry: true) }
        catch CaptureFailure.permissionDenied { detail = "macOS가 현재 실행 중인 앱의 화면 접근을 거부했습니다. 이미 켜져 있다면 앱 등록과 실행 파일의 서명이 달라졌을 수 있습니다." }
        catch { detail = error.localizedDescription }
    }
}
