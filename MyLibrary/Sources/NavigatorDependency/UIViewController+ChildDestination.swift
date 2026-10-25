import NavigationCore
import UIKit
import UIKitNavigation

extension UIViewController {
    /// Declares how to build one of this screen's children from the parent's state, for pushes the
    /// reducer makes through `children` (`ChildNavigator.push(_:as:)`).
    ///
    /// - A push whose request equals `request(item)` shows `content(item)` through `navigator` —
    ///   on this screen's stack (`.push`) or in a new modal (`.present`) — as an entry named by that
    ///   request. Pushing the same child again does nothing.
    /// - When the entry leaves on its own — back, swipe, deep-link reset — sets `item` to `nil`, so a
    ///   TCA parent receives `.dismiss` and its `@Presents` state clears.
    /// - When `item` becomes `nil`, or its `id` changes, removes the entry (and anything above it).
    /// - State that stays set without a push is reported (after `children.missingPushGrace`).
    ///
    /// With TCA, pass `$store.scope(\.child, action: \.child)`; the child keeps talking to its parent
    /// through the parent's reducer (`.ifLet`).
    @discardableResult
    public func childDestination<Item>(
        item: UIBinding<Item?>,
        children: ChildNavigator,
        navigator: any Navigator,
        id: @escaping (Item) -> some Hashable,
        request: @escaping (Item) -> NavigationRequest,
        content: @escaping (Item) -> UIViewController
    ) -> ObserveToken {
        childDestination(
            item: item, children: children, navigator: navigator, id: id, request: request,
            content: content, settle: whenPresentationSettles
        )
    }

    /// `settle` runs its work once nothing is presented over the given screen; tests drive it by hand.
    func childDestination<Item>(
        item: UIBinding<Item?>,
        children: ChildNavigator,
        navigator: any Navigator,
        id: @escaping (Item) -> some Hashable,
        request: @escaping (Item) -> NavigationRequest,
        content: @escaping (Item) -> UIViewController,
        settle: @escaping @MainActor (UIViewController?, @escaping @MainActor () -> Void) -> Void
    ) -> ObserveToken {
        let shown = ShownChild()
        let key = UUID()

        /// Removes the entry of a child the state no longer names.
        let removeStale = {
            let currentID = item.wrappedValue.map { AnyHashable(id($0)) }
            guard let entry = shown.entry, entry.itemID != currentID else { return }
            shown.entry = nil
            guard let entryID = entry.entryID else { return }
            shown.isRemoving = true
            settle(entry.screen) { [weak screen = entry.screen] in
                navigator.remove(entryID)
                popIfStillShown(screen)
                shown.isRemoving = false
                let next = shown.afterRemoval
                shown.afterRemoval = nil
                next?()
            }
        }

        children.destinations[key] = { [weak self] push in
            guard let self, let current = item.wrappedValue, request(current) == push.request else { return false }
            removeStale()
            let currentID = AnyHashable(id(current))
            if shown.entry?.itemID == currentID { return true }

            let entry = ShownEntry(itemID: currentID)
            shown.entry = entry
            let show = { [weak self, weak entry] in
                // Skip if the parent moved on while this waited behind a removal.
                guard let self, let entry, shown.entry === entry else { return }
                let screen = { @MainActor [weak entry] in
                    let screen = content(current)
                    entry?.screen = screen
                    return screen
                }
                let onDismiss = { @MainActor [weak entry] in
                    // The entry left on its own: clear the parent's state, unless it already moved on.
                    guard let entry, shown.entry === entry else { return }
                    shown.entry = nil
                    item.wrappedValue = nil
                }
                entry.entryID = switch push.presentation {
                case .push: navigator.push(local: push.request, from: self, screen: screen, onDismiss: onDismiss)
                case .present: navigator.present(local: push.request, screen: screen, onDismiss: onDismiss)
                }
            }
            // A new child waits until the old one's entry is gone, or the removal would take it too.
            if shown.isRemoving {
                shown.afterRemoval = show
            } else {
                show()
            }
            return true
        }

        children.missingPushChecks[key] = {
            guard let current = item.wrappedValue, shown.entry?.itemID != AnyHashable(id(current)) else { return nil }
            return request(current)
        }

        return observe { [weak children] in
            removeStale()
            guard let children, let grace = children.missingPushGrace,
                  let current = item.wrappedValue, shown.entry?.itemID != AnyHashable(id(current))
            else { return }
            Task { @MainActor [weak children] in
                try? await Task.sleep(for: grace)
                children?.reportMissingPushes()
            }
        }
    }
}

/// The child `childDestination` currently shows, and a removal still in flight.
@MainActor
private final class ShownChild {
    var entry: ShownEntry?
    /// Whether a removal is waiting for a presentation over its screen to settle.
    var isRemoving = false
    /// The child to show once that removal is done.
    var afterRemoval: (() -> Void)?
}

/// One shown child: the identity of its item, its entry once the navigator has it, and its screen.
@MainActor
private final class ShownEntry {
    let itemID: AnyHashable
    var entryID: NavigationEntry.ID?
    weak var screen: UIViewController?

    init(itemID: AnyHashable) {
        self.itemID = itemID
    }
}

/// Runs `work` once nothing is presented over `screen` — `UINavigationController` ignores a pop while
/// something covers its stack. SwiftUI presents a child's alerts from a container (often the window's
/// root), so the whole window is checked, skipping presentations that hold `screen` itself (e.g. the
/// modal it lives in).
///
/// A presentation that is up and not already leaving is closed: it covers a child that is leaving,
/// and a SwiftUI alert whose state went with the child (the delete alert, whose own button cleared
/// it) stays up otherwise. Whether it has gone is checked again shortly rather than trusted to
/// `dismiss`'s completion, which UIKit drops if SwiftUI is dismissing the same alert. After about two
/// seconds `work` runs regardless.
@MainActor
private func whenPresentationSettles(_ screen: UIViewController?, _ work: @escaping @MainActor () -> Void) {
    whenPresentationSettles(screen, attempt: 0, work)
}

@MainActor
private func whenPresentationSettles(_ screen: UIViewController?, attempt: Int, _ work: @escaping @MainActor () -> Void) {
    guard let screen, attempt < 40, let covering = presentation(covering: screen) else { return work() }
    if covering.transitionCoordinator == nil, !covering.isBeingDismissed {
        covering.presentingViewController?.dismiss(animated: true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
        whenPresentationSettles(screen, attempt: attempt + 1, work)
    }
}

/// Makes sure UIKit really dropped a removed child. `UINavigationController` can ignore a pop that
/// lands during another transition (the delete alert closing, a tab or modal animating), leaving the
/// child on screen with no entry; once transitions have settled, this pops it and anything above.
/// Safe with `NavigationStackController`: the entry is already gone from its path, which a pop only
/// ever shortens.
@MainActor
private func popIfStillShown(_ screen: UIViewController?, attempt: Int = 0) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(attempt == 0 ? 400 : 150)) { [weak screen] in
        guard let screen, let navigationController = screen.navigationController,
              let index = navigationController.viewControllers.firstIndex(of: screen), index > 0
        else { return }
        guard navigationController.transitionCoordinator == nil, presentation(covering: screen) == nil else {
            if attempt < 20 { popIfStillShown(screen, attempt: attempt + 1) }
            return
        }
        navigationController.popToViewController(navigationController.viewControllers[index - 1], animated: true)
    }
}

/// The first presentation in `screen`'s window that doesn't contain `screen`.
@MainActor
private func presentation(covering screen: UIViewController) -> UIViewController? {
    var presented = screen.view.window?.rootViewController?.presentedViewController
    while let candidate = presented {
        if !screen.isInside(candidate) { return candidate }
        presented = candidate.presentedViewController
    }
    return nil
}

extension UIViewController {
    /// Whether `container` is this controller or one of its ancestors.
    fileprivate func isInside(_ container: UIViewController) -> Bool {
        var current: UIViewController? = self
        while let controller = current {
            if controller === container { return true }
            current = controller.parent
        }
        return false
    }
}
