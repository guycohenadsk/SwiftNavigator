import UIKit

/// What a resolver knows besides the request: the navigator, the screen the request was pushed from,
/// and a way to act once the screen it builds leaves.
@MainActor
public struct NavigationContext {
    public let navigator: any Navigator
    /// The screen on top of the stack when the request landed — the one that pushed it — so a module
    /// can build a child from its parent, e.g. scoping the parent's store. `nil` for a stack's root.
    public let parent: UIViewController?
    private let leave: (@escaping @MainActor () -> Void) -> Void

    public init(
        navigator: any Navigator,
        parent: UIViewController? = nil,
        onLeave: @escaping (@escaping @MainActor () -> Void) -> Void = { _ in }
    ) {
        self.navigator = navigator
        self.parent = parent
        self.leave = onLeave
    }

    /// Runs `action` once the entry of the screen being resolved leaves, however it leaves — pop,
    /// swipe-back, `complete(with:)`, a deep-link reset. Does nothing for a stack's root.
    public func onLeave(_ action: @escaping @MainActor () -> Void) {
        leave(action)
    }
}
