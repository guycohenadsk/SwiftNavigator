import UIKit

@MainActor
public final class NavigationRegistry {
    private var resolvers: [NavigationTarget: NavigationResolver] = [:]
    private var actions: [NavigationTarget: [String: NavigationAction]] = [:]

    public init() {}

    public func register(_ registration: NavigationRegistration) throws {
        guard resolvers[registration.target] == nil else {
            throw NavigationError.duplicateRegistration(registration.target)
        }
        resolvers[registration.target] = registration.resolver
        actions[registration.target] = registration.actions
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

    /// Runs the action a `.perform` request names. Throws for any other intent, an unregistered
    /// target, or an action the module does not declare.
    public func perform(_ request: NavigationRequest, navigator: any Navigator) throws {
        guard case let .perform(target, name) = request.intent else { throw NavigationError.unsupportedIntent }
        guard let moduleActions = actions[target] else { throw NavigationError.unregisteredTarget(target) }
        guard let action = moduleActions[name] else { throw NavigationError.unsupportedIntent }
        action(navigator)
    }
}
