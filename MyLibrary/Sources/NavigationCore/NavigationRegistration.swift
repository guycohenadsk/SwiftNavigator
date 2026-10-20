import UIKit

public typealias NavigationResolver = @MainActor @Sendable (NavigationRequest, any Navigator) throws -> UIViewController

/// How one module takes part in navigation: its target and its resolver. Each feature owns one as a
/// plain value; the app shell only lists them.
public struct NavigationRegistration: Sendable {
    public let target: NavigationTarget
    public let resolver: NavigationResolver

    public init(target: NavigationTarget, resolver: @escaping NavigationResolver) {
        self.target = target
        self.resolver = resolver
    }
}
