import NavigationCore

/// Screen D's routes. Imported only by Screen D itself.
public enum ScreenDNavigationContract {
    public static let target: NavigationTarget = .screenD

    public enum Route: NavigationRoute {
        public static var target: NavigationTarget { ScreenDNavigationContract.target }


        case home
    }
}
