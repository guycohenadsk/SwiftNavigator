import Foundation

/// One module's `Route`, boxed so the navigator, stacks and registry can carry any module's routes
/// without knowing them. The module reads it back with `route(as:)`.
///
/// Encodes as its target and route. The core can't name a module's `Route` type, so decoding needs
/// the types of the registered modules in `userInfo[.navigationRouteTypes]`
/// (`NavigationRegistry.routeTypes`).
public struct NavigationRequest: Hashable, Sendable, Codable {
    public let target: NavigationTarget
    private let value: any NavigationRoute

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

    private enum CodingKeys: String, CodingKey {
        case target, route
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        target = try container.decode(NavigationTarget.self, forKey: .target)
        let routeTypes = decoder.userInfo[.navigationRouteTypes] as? [NavigationTarget: any NavigationRoute.Type]
        guard let routeType = routeTypes?[target] else {
            throw DecodingError.dataCorruptedError(
                forKey: .target, in: container,
                debugDescription: "No route type for \(target); pass NavigationRegistry.routeTypes in userInfo."
            )
        }
        value = try container.decode(routeType, forKey: .route)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(target, forKey: .target)
        try container.encode(value, forKey: .route)
    }
}

extension CodingUserInfoKey {
    /// `[NavigationTarget: any NavigationRoute.Type]`, needed to decode a `NavigationRequest`.
    public static let navigationRouteTypes = CodingUserInfoKey(rawValue: "navigationRouteTypes")!
}
