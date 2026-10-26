import NavigationCore

/// Screen B's routes and inner screens. Imported only by Screen B itself.
public enum ScreenBNavigationContract {
    public static let target: NavigationTarget = .screenB

    public enum Route: Hashable {
        case home
        case b2
    }

    /// Screen B's inner screens, pushed by Screen B itself and resolved by its registration.
    public enum Screen: String {
        case b2
    }

    /// The stack entry of one of Screen B's inner screens.
    public static func request(for screen: Screen) -> NavigationRequest {
        NavigationRequest(intent: .screen(target, name: screen.rawValue))
    }
}
