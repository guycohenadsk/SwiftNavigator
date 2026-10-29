import UIKit

public typealias NavigationResolver = @MainActor @Sendable (NavigationRequest, NavigationContext) throws -> UIViewController

/// A deep link addressed to one module: what follows `demoapp://<target>`.
public struct DeepLink: Hashable, Sendable {
    public let target: NavigationTarget
    /// `demoapp://issues/abc` → `["abc"]`.
    public let path: [String]
    /// `demoapp://issues?action=x` → `["action": "x"]`.
    public let query: [String: String]

    public init(target: NavigationTarget, path: [String] = [], query: [String: String] = [:]) {
        self.target = target
        self.path = path
        self.query = query
    }
}

/// How one module takes part in navigation: its routes, the deep links it understands, and its
/// resolver. Each feature owns one as a plain value; the app shell only lists them.
public struct NavigationRegistration: Sendable {
    public let target: NavigationTarget
    public let resolver: NavigationResolver
    /// Turns a deep link into one of the module's routes, or `nil` if the module doesn't offer it.
    public let deepLink: @Sendable (DeepLink) -> NavigationRequest?
    /// Deep-link requests to hand to the module's root screen (`Navigator.incomingRequests(for:)`)
    /// instead of resolving and pushing them — so the root can open them as its own children.
    public let deepLinksToRoot: @MainActor @Sendable (NavigationRequest) -> Bool

    /// - Parameters:
    ///   - deepLink: the module's URL grammar; return `nil` for links it doesn't support.
    ///   - toRoot: routes that a deep link hands to the root screen rather than pushing.
    ///   - resolver: builds the screen for one of the module's routes.
    public init<Route: NavigationRoute>(
        _: Route.Type,
        deepLink: @escaping @Sendable (DeepLink) -> Route? = { _ in nil },
        toRoot: @escaping @MainActor @Sendable (Route) -> Bool = { _ in false },
        resolver: @escaping @MainActor @Sendable (Route, NavigationContext) throws -> UIViewController
    ) {
        target = Route.target
        self.deepLink = { link in deepLink(link).map { NavigationRequest($0) } }
        deepLinksToRoot = { request in request.route(as: Route.self).map(toRoot) ?? false }
        self.resolver = { request, context in
            guard let route = request.route(as: Route.self) else { throw NavigationError.wrongTarget }
            return try resolver(route, context)
        }
    }
}
