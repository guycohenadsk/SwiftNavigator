import NavigationCore

/// Screen C's routes. Imported only by Screen C itself.
public enum ScreenCNavigationContract {
    public static let target: NavigationTarget = .screenC

    public enum Route: Hashable {
        case home
        /// A text field and Send; each Send goes back to the caller as `.message`.
        case compose(prompt: String)
    }
}
