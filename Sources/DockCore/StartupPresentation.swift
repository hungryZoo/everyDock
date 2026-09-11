public enum StartupPresentation: Equatable, Sendable {
    case onboarding, settings, background

    public static func resolve(hasLaunched: Bool, loginLaunch: Bool, hidesMenuIcon: Bool, needsPermissionGuidance: Bool = false) -> Self {
        if !hasLaunched || needsPermissionGuidance { return .onboarding }
        if hidesMenuIcon && !loginLaunch { return .settings }
        return .background
    }
}
