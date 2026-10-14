import NavigationCore

/// Screen D's routes. Imported only by Screen D itself.
public enum ScreenDNavigationContract {
    public static let target: NavigationTarget = .screenD

    public enum Route: Hashable {
        case home
    }
}
