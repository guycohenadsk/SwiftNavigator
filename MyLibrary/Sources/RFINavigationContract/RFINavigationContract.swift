import NavigationCore

/// The RFI module's routes. Any feature may import this to navigate to RFIs.
public enum RFINavigationContract {
    public enum Route: NavigationRoute {
        public static let target = NavigationTarget.rfi

        case list
        /// The list in picker mode: completes with `.selectedEntity` of the tapped RFI.
        case pick
        /// A stored RFI's detail, standalone: it saves and deletes on its own.
        case open(id: String)
    }
}
