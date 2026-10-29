import NavigationCore

/// Screen B's routes. Any feature may import this to navigate to Screen B.
public enum ScreenBNavigationContract {
    public enum Route: NavigationRoute {
        case home
        /// Screen B's inner screen, pushed by Screen B itself.
        case b2

        public static let target: NavigationTarget = .screenB
    }
}
