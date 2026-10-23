import NavigationCore
import UIKit
import UIKitNavigation

extension UIViewController {
    /// Pushes a child through the `Navigator` while its parent keeps owning the child's state — the
    /// navigator-driven version of `navigationDestination(item:)`.
    ///
    /// - When `item` becomes non-`nil`, pushes `content(item)` with `navigator.push(local:…)`, next
    ///   to this controller, as an entry named `request(item)`.
    /// - When `item` becomes `nil`, or its `id` changes, removes that entry (and anything above it);
    ///   a new item is then pushed in its place. Other changes (e.g. editing the item's title) leave
    ///   the entry alone — `request` is read once, at push time.
    /// - When the entry leaves on its own — back button, swipe-back, deep-link reset — sets `item` to
    ///   `nil`, so a TCA parent receives `.dismiss` and its `@Presents` state clears.
    ///
    /// With TCA, pass `$store.scope(\.child, action: \.child)` and the child keeps talking to its
    /// parent through the parent's reducer (`.ifLet`), exactly as with in-place presentation.
    @discardableResult
    public func navigatorDestination<Item>(
        item: UIBinding<Item?>,
        navigator: any Navigator,
        id: @escaping (Item) -> some Hashable,
        request: @escaping (Item) -> NavigationRequest,
        content: @escaping (Item) -> UIViewController
    ) -> ObserveToken {
        navigatorDestination(item: item, navigator: navigator, id: id, request: request, content: content, settle: whenPresentationSettles)
    }

    /// `settle` runs its work once nothing is presented over the given screen; tests drive it by hand.
    func navigatorDestination<Item>(
        item: UIBinding<Item?>,
        navigator: any Navigator,
        id: @escaping (Item) -> some Hashable,
        request: @escaping (Item) -> NavigationRequest,
        content: @escaping (Item) -> UIViewController,
        settle: @escaping @MainActor (UIViewController?, @escaping @MainActor () -> Void) -> Void
    ) -> ObserveToken {
        let pushed = PushedEntry()
        return observe { [weak self] in
            guard let self else { return }
            let current = item.wrappedValue
            let currentID = current.map { AnyHashable(id($0)) }

            if let push = pushed.push, push.itemID != currentID {
                pushed.push = nil
                if let entryID = push.entryID {
                    pushed.isRemoving = true
                    settle(push.screen) {
                        navigator.remove(entryID)
                        pushed.isRemoving = false
                        let next = pushed.afterRemoval
                        pushed.afterRemoval = nil
                        next?()
                    }
                }
            }
            guard let current, let currentID, pushed.push == nil else { return }

            let push = Push(itemID: currentID)
            pushed.push = push
            let perform = { [weak self, weak push] in
                // Skip if the parent moved on while this push waited behind a removal.
                guard let self, let push, pushed.push === push else { return }
                push.entryID = navigator.push(local: request(current), from: self) { [weak push] in
                    let screen = content(current)
                    push?.screen = screen
                    return screen
                } onDismiss: { [weak push] in
                    // The entry left on its own: clear the parent's state, unless it already moved on.
                    guard let push, pushed.push === push else { return }
                    pushed.push = nil
                    item.wrappedValue = nil
                }
            }
            // A new child waits until the old one's entry is gone, or the removal would take it too.
            if pushed.isRemoving {
                pushed.afterRemoval = perform
            } else {
                perform()
            }
        }
    }
}

/// The entry `navigatorDestination` currently has on the stack, and a removal still in flight.
@MainActor
private final class PushedEntry {
    var push: Push?
    /// Whether a removal is waiting for a presentation over its screen to settle.
    var isRemoving = false
    /// The push to make once that removal is done.
    var afterRemoval: (() -> Void)?
}

/// One push: the identity of the item it shows, and its entry once the navigator has it.
@MainActor
private final class Push {
    let itemID: AnyHashable
    var entryID: NavigationEntry.ID?
    /// The pushed screen, once the stack has built it.
    weak var screen: UIViewController?

    init(itemID: AnyHashable) {
        self.itemID = itemID
    }
}

/// Runs `work` once nothing is presenting or being dismissed over `screen` — `UINavigationController`
/// drops a pop that lands while, say, an alert on the popped screen is still animating away.
@MainActor
private func whenPresentationSettles(_ screen: UIViewController?, _ work: @escaping @MainActor () -> Void) {
    guard let screen, let presented = screen.presentedViewController else { return work() }
    if let coordinator = presented.transitionCoordinator {
        coordinator.animate(alongsideTransition: nil) { _ in
            whenPresentationSettles(screen, work)
        }
    } else {
        screen.dismiss(animated: true) { work() }
    }
}
