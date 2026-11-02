import NavigationCore

/// The Issues module's routes. Any feature may import this to navigate to Issues.
public enum IssuesNavigationContract {
    public enum Route: NavigationRoute {
        case list
        /// The list in picker mode: completes with `.selectedEntity` of the tapped issue.
        case pick
        /// A stored issue's detail, standalone: it saves and deletes on its own.
        case open(id: String)
        /// A stored issue picked at random, shown like `.open` of that issue.
        case random
        /// The list's own detail, built from the list's store: the list owns its state.
        case listDetails(id: String)
        /// Handed to the list at the tab's root, which pushes Screen C as its Context chip does.
        case screenCContext

        public static let target: NavigationTarget = .issues
    }
}
