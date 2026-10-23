import UIKit

@MainActor
public final class NavigationRegistry {
    private var resolvers: [NavigationTarget: NavigationResolver] = [:]
    private var deepLinksToRoot: [NavigationTarget: @MainActor @Sendable (NavigationRequest) -> Bool] = [:]

    public init() {}

    public func register(_ registration: NavigationRegistration) throws {
        guard resolvers[registration.target] == nil else {
            throw NavigationError.duplicateRegistration(registration.target)
        }
        resolvers[registration.target] = registration.resolver
        deepLinksToRoot[registration.target] = registration.deepLinksToRoot
    }

    /// Whether the module `request` targets wants this deep link handed to its root screen.
    public func deepLinksToRoot(_ request: NavigationRequest) -> Bool {
        deepLinksToRoot[request.target]?(request) ?? false
    }

    public var registeredTargets: Set<NavigationTarget> {
        Set(resolvers.keys)
    }

    public func resolve(_ request: NavigationRequest, navigator: any Navigator) throws -> UIViewController {
        guard let resolver = resolvers[request.target] else {
            throw NavigationError.unregisteredTarget(request.target)
        }
        return try resolver(request, navigator)
    }
}
