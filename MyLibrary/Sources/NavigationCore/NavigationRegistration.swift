import UIKit

public typealias NavigationResolver = @MainActor @Sendable (NavigationRequest, NavigationContext) throws -> UIViewController

/// How one module takes part in navigation: its target, its resolver, and which deep links its root
/// screen handles itself. Each feature owns one as a plain value; the app shell only lists them.
public struct NavigationRegistration: Sendable {
    public let target: NavigationTarget
    public let resolver: NavigationResolver
    /// Deep-link requests to hand to the module's root screen (`Navigator.incomingRequests(for:)`)
    /// instead of resolving and pushing them — so the root can open them as its own children.
    /// Only for modules that are a tab root; elsewhere the link is resolved as usual.
    public let deepLinksToRoot: @MainActor @Sendable (NavigationRequest) -> Bool

    public init(
        target: NavigationTarget,
        deepLinksToRoot: @escaping @MainActor @Sendable (NavigationRequest) -> Bool = { _ in false },
        resolver: @escaping NavigationResolver
    ) {
        self.target = target
        self.deepLinksToRoot = deepLinksToRoot
        self.resolver = resolver
    }
}
