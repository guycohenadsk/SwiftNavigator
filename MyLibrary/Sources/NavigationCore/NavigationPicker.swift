/// A module's offer to let the user pick one of its entities, declared in its registration. The
/// request is answered with `.selectedEntity`, so a shared component such as the Ref Picker can
/// pick from any module that offers one without knowing its routes.
public struct NavigationPicker: Hashable, Sendable {
    /// What one entity is called, e.g. "RFI".
    public let title: String
    public let request: NavigationRequest

    public var target: NavigationTarget { request.target }

    public init<Route: NavigationRoute>(title: String, route: Route) {
        self.title = title
        self.request = NavigationRequest(route)
    }
}
