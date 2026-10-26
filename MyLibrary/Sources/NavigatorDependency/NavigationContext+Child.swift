import ComposableArchitecture
import NavigationCore
import UIKit

extension NavigationContext {
    /// Builds a parent's child screen — whose state the parent owns (`@Presents` + `.ifLet`) — from the
    /// parent's store, scoped to the child, and clears that state when the screen leaves.
    ///
    /// For a resolver: the parent's reducer sets the child state and pushes `request` through the
    /// navigator; the resolver finds the parent's store through `parent` and calls this. When the
    /// entry leaves — back, swipe-back, a deep-link reset — this sends the child's `.dismiss`, so the
    /// reducer needs no action for it. Nothing is sent if the state no longer shows that child: the
    /// parent already cleared it (and popped), or moved on to another child.
    ///
    /// Returns `nil` when the parent's state doesn't show the child `request` is for — pushed without
    /// setting the state first.
    public func child<State: ObservableState, Action, ChildState, ChildAction>(
        for request: NavigationRequest,
        of store: Store<State, Action>,
        state: KeyPath<State, ChildState?>,
        action: CaseKeyPath<Action, PresentationAction<ChildAction>>,
        requestOf childRequest: @escaping @MainActor (ChildState) -> NavigationRequest,
        content: (Store<ChildState, ChildAction>) -> UIViewController
    ) -> UIViewController? {
        /// Whether `store` currently shows the child `request` was pushed for.
        @MainActor
        func shows(in store: Store<State, Action>) -> Bool {
            store.withState { $0[keyPath: state] }.map(childRequest) == request
        }

        guard shows(in: store), let child = store.scope(state, action: action.appending(path: \.presented)) else {
            return nil
        }
        onLeave { [weak store] in
            guard let store, shows(in: store) else { return }
            store.send(action(.dismiss))
        }
        return content(child)
    }
}
