/// The only navigation seam a feature module depends on. Features never import each other or the
/// screen resolver directly — they ask the Navigator to move, and it's the composition root's job
/// to decide what that means.
@MainActor
public protocol Navigator: Sendable {
    func push(_ destination: Destination)
    func pop()
    func popToRoot()

    /// Presents `destination` modally in its own, self-contained navigation stack. Pushes made
    /// while something is presented land in that stack, not whichever tab was active beforehand.
    func present(_ destination: Destination)
    func dismiss()
}

extension Navigator {
    /// Convenience for context-free navigation from the `Route` catalog, so "go to any screen"
    /// call sites stay a one-liner.
    public func push(_ route: Route) {
        push(Destination(route))
    }

    public func present(_ route: Route) {
        present(Destination(route))
    }
}
