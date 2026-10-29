/// One module's `Route`, boxed so the navigator, stacks and registry can carry any module's routes
/// without knowing them. The module reads it back with `route(as:)`.
public struct NavigationRequest: Hashable, Sendable {
    public let target: NavigationTarget
    private let value: any Hashable & Sendable

    public init<Route: NavigationRoute>(_ route: Route) {
        target = Route.target
        value = route
    }

    /// The route, if this request carries a `Route`.
    public func route<Route: NavigationRoute>(as _: Route.Type = Route.self) -> Route? {
        value as? Route
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.target == rhs.target && AnyHashable(lhs.value) == AnyHashable(rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(target)
        hasher.combine(AnyHashable(value))
    }
}
