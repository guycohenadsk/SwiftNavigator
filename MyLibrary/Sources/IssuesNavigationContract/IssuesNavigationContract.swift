import NavigationCore

/// The Issues module's routes. Imported only by Issues itself — other features reach Issues
/// through `NavigationIntent` alone, importing nothing but NavigationCore.
public enum IssuesNavigationContract {
    public static let target: NavigationTarget = .issues

    public enum Route: Hashable {
        case list
        case picker
        case details(id: String)
    }
}
