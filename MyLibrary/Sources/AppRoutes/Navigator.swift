/// The only navigation seam a feature module depends on. Features never import each other or the
/// screen resolver directly — they ask the Navigator to move, and it's the composition root's job
/// to decide what that means.
@MainActor
public protocol Navigator: Sendable {
    func push(_ route: Route)
    func pop()
    func popToRoot()

    /// Presents `route` modally in its own, self-contained navigation stack. Pushes made while a
    /// route is presented land in that stack, not whichever tab was active beforehand.
    func present(_ route: Route)
    func dismiss()
}
