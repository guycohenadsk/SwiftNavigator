import NavigationCore

/// Screen B's routes. Imported only by Screen B itself.
public enum ScreenBNavigationContract {
    public static let target: NavigationTarget = .screenB

    public enum Route: Hashable {
        case home
    }
}
