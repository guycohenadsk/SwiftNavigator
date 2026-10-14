import UIKit

public typealias NavigationResolver = @MainActor @Sendable (NavigationRequest, any Navigator) throws -> UIViewController
public typealias NavigationAction = @MainActor @Sendable (any Navigator) -> Void

/// How one module takes part in navigation: its target, its resolver, and any named actions a deep
/// link can ask it to run. Each feature owns one as a plain value; the app shell only lists them.
public struct NavigationRegistration: Sendable {
    public let target: NavigationTarget
    public let resolver: NavigationResolver
    public let actions: [String: NavigationAction]

    public init(target: NavigationTarget, actions: [String: NavigationAction] = [:], resolver: @escaping NavigationResolver) {
        self.target = target
        self.actions = actions
        self.resolver = resolver
    }
}
