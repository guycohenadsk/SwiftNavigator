import NavigationCore

/// The Issues module's routes. Imported only by Issues itself — other features reach Issues
/// through `NavigationIntent` alone, importing nothing but NavigationCore.
public enum IssuesNavigationContract {
    public static let target: NavigationTarget = .issues

    public enum Route: Hashable {
        case list
        case picker
        case details(id: String)
        /// A stored issue picked at random, shown like `.details` of that issue.
        case randomDetails
        /// The list's own detail, built from the list's store: the list owns its state.
        case listDetails(id: String)
    }
}
