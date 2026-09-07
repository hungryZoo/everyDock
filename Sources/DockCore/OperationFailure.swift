import Foundation
import ApplicationServices
import ScreenCaptureKit

/// An unavailable window is not evidence that the user denied Accessibility.
public enum WindowFailure: Error, Equatable, Sendable {
    case permissionDenied, noWindow, unsupported, timedOut, apiError(Int32)

    public static func classify(_ error: AXError) -> Self {
        switch error {
        case .apiDisabled: .permissionDenied
        case .noValue: .noWindow
        case .attributeUnsupported, .actionUnsupported, .notImplemented: .unsupported
        case .cannotComplete: .timedOut
        default: .apiError(error.rawValue)
        }
    }
}

public enum CaptureFailure: Error, Equatable, Sendable {
    case permissionDenied
    case unavailable(String)

    public static func classify(_ error: any Error) -> Self {
        let error = error as NSError
        if error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue {
            return .permissionDenied
        }
        return .unavailable("\(error.domain) (\(error.code)): \(error.localizedDescription)")
    }
}
