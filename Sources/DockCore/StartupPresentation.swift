public enum StartupPresentation: Equatable, Sendable {
    case onboarding, settings, background

    public static func resolve(hasLaunched: Bool, loginLaunch: Bool, hidesMenuIcon: Bool) -> Self {
        if !hasLaunched { return .onboarding }
        if hidesMenuIcon && !loginLaunch { return .settings }
        return .background
    }
}
