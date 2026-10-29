/// What a module can be asked to show, declared by the module's own contract (e.g.
/// `IssuesNavigationContract.Route`). The core only carries it, so a module's capabilities are
/// exactly the cases of its `Route` — nothing in the core changes when a module adds one.
public protocol NavigationRoute: Hashable, Sendable {
    static var target: NavigationTarget { get }
}
