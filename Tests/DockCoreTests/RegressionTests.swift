import Foundation
import ApplicationServices
import ScreenCaptureKit
import Testing
@testable import DockCore

@Test func permissionDenialIsNotAWindowCapabilityError() {
    #expect(WindowFailure.classify(.apiDisabled) == .permissionDenied)
    #expect(WindowFailure.classify(.cannotComplete) == .timedOut)
    #expect(WindowFailure.classify(.noValue) == .noWindow)
    for error: AXError in [.attributeUnsupported, .actionUnsupported, .notImplemented] {
        #expect(WindowFailure.classify(error) == .unsupported)
    }
    #expect(WindowFailure.classify(.invalidUIElement) == .apiError(AXError.invalidUIElement.rawValue))
}

@Test func onlyScreenCaptureUserDeclinedMeansPermissionDenied() {
    let code = SCStreamError.Code.userDeclined.rawValue
    #expect(CaptureFailure.classify(NSError(domain: SCStreamErrorDomain, code: code)) == .permissionDenied)
    #expect(CaptureFailure.classify(NSError(domain: "DifferentDomain", code: code)) != .permissionDenied)
    #expect(CaptureFailure.classify(NSError(domain: SCStreamErrorDomain, code: -3802)) != .permissionDenied)
    #expect(CaptureFailure.classify(CancellationError()) != .permissionDenied)
}

@Test func animationProgressDependsOnTimeNotRefreshRate() {
    func advance(_ intervals: [Double]) -> Double {
        intervals.reduce(1.0) { value, dt in value + (2.5 - value) * DockMotion.interpolation(elapsed: dt) }
    }
    let sixty = advance(Array(repeating: 1.0 / 60, count: 30))
    let oneTwenty = advance(Array(repeating: 1.0 / 120, count: 60))
    let variable = advance([0.1, 0.05, 0.2, 0.15])
    #expect(abs(sixty - oneTwenty) < 1e-12)
    #expect(abs(sixty - variable) < 1e-12)
    #expect(DockMotion.interpolation(elapsed: 0) == 0)
    #expect(DockMotion.interpolation(elapsed: -1) == 0)
}

@Test func panelAlignmentIsStableAcrossFractionalAndNegativeCoordinates() {
    let input = CGRect(x: -1711.333, y: -222.667, width: 1030.333, height: 177.55)
    for scale in [1.0, 2.0] {
        let aligned = DockMetrics.aligned(input, scale: scale)
        #expect(DockMetrics.aligned(aligned, scale: scale) == aligned)
        for coordinate in [aligned.minX, aligned.minY, aligned.width, aligned.height] {
            #expect(coordinate * scale == (coordinate * scale).rounded())
        }
        #expect(abs(aligned.midX - input.midX) <= 0.75 / scale)
    }
}
