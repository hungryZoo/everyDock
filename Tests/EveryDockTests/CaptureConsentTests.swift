import Testing
import Foundation
import ScreenCaptureKit
import DockCore
@testable import EveryDock

@MainActor @Test func backgroundCaptureNeverRequestsMissingPermission() async {
    var requests = 0
    let permissions = AppPermissions(capturePreflight: { false }, loadContent: {
        requests += 1
        throw NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
    })
    for _ in 0..<10 {
        permissions.refreshHints()
        do { _ = try await permissions.shareableContent(retry: true); Issue.record("Unexpected capture") }
        catch { #expect(error as? CaptureFailure == .permissionRequired) }
    }
    #expect(requests == 0)
    #expect(permissions.capture == .unknown)
    #expect(permissions.needsGuidance)
    do { _ = try await permissions.shareableContent(requestPermission: true) } catch {}
    #expect(requests == 1)
    #expect(permissions.capture == .denied)
    for _ in 0..<10 { do { _ = try await permissions.shareableContent() } catch {} }
    #expect(requests == 1)
}

@MainActor @Test func denialAndRevocationStopBackgroundCaptureEvenWithStaleHints() async {
    var granted = true
    var requests = 0
    let permissions = AppPermissions(capturePreflight: { granted }, loadContent: {
        requests += 1
        throw NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
    })
    #expect(permissions.canCaptureWithoutPrompt)
    granted = false
    #expect(!permissions.canCaptureWithoutPrompt)
    do { _ = try await permissions.shareableContent() } catch {}
    #expect(requests == 0)
    granted = true
    do { _ = try await permissions.shareableContent() } catch {}
    #expect(requests == 1)
    permissions.refreshHints()
    #expect(!permissions.canCaptureWithoutPrompt)
    do { _ = try await permissions.shareableContent(retry: true) } catch {}
    #expect(requests == 1)
    do { _ = try await permissions.shareableContent(requestPermission: true) } catch {}
    #expect(requests == 2)
}
