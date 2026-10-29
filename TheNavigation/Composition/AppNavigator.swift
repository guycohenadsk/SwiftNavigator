import Foundation
import NavigationCore
import Observation
import UIKit

/// One back stack — a tab's or a modal's: a path, the result handlers of its entries, and a `didSet`
/// that reports `.dismissed` for every entry that disappears however it disappeared (pop,
/// swipe-back, reset).
@MainActor
@Observable
final class StackNavigator {
    var path: [NavigationEntry] = [] {
        didSet {
            let removedIDs = Set(oldValue.map(\.id)).subtracting(path.map(\.id))
            for id in removedIDs {
                leaveActions.removeValue(forKey: id)?()
                handlers.removeValue(forKey: id)?(.dismissed)
            }
        }
    }
    @ObservationIgnored private var handlers: [UUID: NavigationResultHandler] = [:]
    /// What to run when an entry leaves (`NavigationContext.onLeave`).
    @ObservationIgnored private var leaveActions: [UUID: @MainActor () -> Void] = [:]
    /// The UIKit stack bound to `path`, so removals can wait for what covers it.
    @ObservationIgnored weak var controller: UINavigationController?

    #if DEBUG
    /// For the memory tests: what this stack still holds on to for its entries.
    var handlerCount: Int { handlers.count }
    var leaveActionCount: Int { leaveActions.count }
    #endif

    /// Runs `action` once the entry `id` leaves, however it leaves.
    func onLeave(_ id: UUID, _ action: @escaping @MainActor () -> Void) {
        leaveActions[id] = action
    }

    func push(_ entry: NavigationEntry, onResult: NavigationResultHandler?) {
        handlers[entry.id] = onResult
        path.append(entry)
    }

    /// Hands an update to whoever pushed the top entry, leaving it in place.
    func send(_ result: NavigationResult) {
        guard let last = path.last else { return }
        handlers[last.id]?(result)
    }

    /// Removes the top entry and hands `result` to whoever pushed it — right away, while the entry
    /// itself leaves once nothing covers the stack (see `removeWhenUncovered(_:)`).
    func complete(with result: NavigationResult) {
        guard let last = path.last else { return }
        let handler = handlers.removeValue(forKey: last.id)
        removeWhenUncovered(last.id)
        handler?(result)
    }

    /// Removes the top entry; its handler gets `.dismissed`.
    func pop() {
        guard let last = path.last else { return }
        removeWhenUncovered(last.id)
    }

    /// Removes `id` and everything above it once nothing is presented over this stack:
    /// `UINavigationController` ignores a pop while something covers it — e.g. the delete alert a
    /// screen closes itself from, still animating away.
    private func removeWhenUncovered(_ id: UUID) {
        whenUncovered(controller) { [weak self] in
            guard let self, let index = path.firstIndex(where: { $0.id == id }) else { return }
            path.removeSubrange(index...)
        }
    }
}

/// One modal level: the entry it was presented with, and its own back stack.
@MainActor
@Observable
final class ModalNavigator: Identifiable {
    let root: NavigationEntry
    let stack = StackNavigator()
    @ObservationIgnored var onResult: NavigationResultHandler?
    var id: UUID { root.id }

    init(root: NavigationEntry, onResult: NavigationResultHandler?) {
        self.root = root
        self.onResult = onResult
    }
}

/// The app's `Navigator`: one stack per tab, plus modals stacked on top. Every call goes to the
/// current stack — the top modal's, else the selected tab's.
@MainActor
@Observable
final class AppNavigator: Navigator {
    var tabIndex = 0
    let tabs: [StackNavigator]
    @ObservationIgnored let tabRoots: [NavigationRequest]
    /// Who listens for deep links: a target, and the stack whose root screen subscribed.
    @ObservationIgnored private var rootSubscribers: [UUID: RootSubscriber] = [:]
    /// Deep links that landed before their stack's root subscribed.
    @ObservationIgnored private var pendingRequests: [PendingRequest] = []
    /// Whether a deep link goes to its module's root screen rather than being pushed. AppComposition
    /// wires it to what each registration declares (`NavigationRegistry.deepLinksToRoot`).
    @ObservationIgnored var deepLinksToRoot: (NavigationRequest) -> Bool = { _ in false }

    var modals: [ModalNavigator] = [] {
        didSet {
            // Dismissed however it happened (dismiss(), swipe-down, deep link): report `.dismissed`
            // for the modal and everything pushed inside it.
            let remaining = Set(modals.map(\.id))
            for modal in oldValue where !remaining.contains(modal.id) {
                modal.stack.path = []
                modal.onResult?(.dismissed)
                modal.onResult = nil
            }
        }
    }

    init(tabRoots: [NavigationRequest]) {
        self.tabRoots = tabRoots
        self.tabs = tabRoots.map { _ in StackNavigator() }
    }

    private var current: StackNavigator { modals.last?.stack ?? tabs[tabIndex] }

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        current.push(NavigationEntry(request: request), onResult: onResult)
    }

    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        modals.append(ModalNavigator(root: NavigationEntry(request: request), onResult: onResult))
    }

    func send(_ result: NavigationResult) {
        if let modal = modals.last, modal.stack.path.isEmpty {
            modal.onResult?(result)
        } else {
            current.send(result)
        }
    }

    func complete(with result: NavigationResult) {
        guard result.isFinal else {
            // An output is never final: deliver it, then leave with `.dismissed`.
            send(result)
            complete(with: .dismissed)
            return
        }
        if let modal = modals.last, modal.stack.path.isEmpty {
            // The top screen is the modal's root: completing it dismisses the modal.
            let handler = modal.onResult
            modal.onResult = nil
            modals.removeLast()
            handler?(result)
        } else {
            current.complete(with: result)
        }
    }

    func pop() { current.pop() }
    func popToRoot() { current.path.removeAll() }
    func dismiss() { _ = modals.popLast() }

    #if DEBUG
    /// For the memory tests: the deep-link subscriptions and held deep links still around.
    var rootSubscriberCount: Int { rootSubscribers.count }
    var pendingRequestCount: Int { pendingRequests.count }
    #endif

    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> {
        let (stream, continuation) = AsyncStream<NavigationRequest>.makeStream()
        let id = UUID()
        let subscriber = RootSubscriber(target: target, stack: current, isRoot: current.path.isEmpty, continuation: continuation)
        rootSubscribers[id] = subscriber
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.rootSubscribers[id] = nil }
        }
        pendingRequests.removeAll { pending in
            guard subscriber.receives(pending.request.target, on: pending.stack) else { return false }
            continuation.yield(pending.request)
            return true
        }
        return stream
    }

    /// Lands a deep link: dismiss modals, switch to the tab whose root is that module (if any) on a
    /// fresh stack, then push the request — unless that tab's root already is the request, or the
    /// root screen handles it itself (`deepLinksToRoot`), in which case it goes to that root through
    /// `incomingRequests(for:)` — on the current stack when the module has no tab.
    func open(deepLink request: NavigationRequest) {
        modals = []
        let toRoot = deepLinksToRoot(request)
        if let tab = tabRoots.firstIndex(where: { $0.target == request.target }) {
            tabIndex = tab
            tabs[tab].path = []
            if tabRoots[tab] == request { return }
            if toRoot {
                deliver(request, on: tabs[tab])
                return
            }
        } else if toRoot {
            deliver(request, on: current)
            return
        }
        push(request)
    }

    /// Hands `request` to the root screen of `stack` listening for its target, or holds it until one
    /// subscribes.
    private func deliver(_ request: NavigationRequest, on stack: StackNavigator) {
        if let subscriber = rootSubscribers.values.first(where: { $0.receives(request.target, on: stack) }) {
            subscriber.continuation.yield(request)
        } else {
            pendingRequests.append(PendingRequest(request: request, stack: stack))
        }
    }

    /// The modal at `level`, as an optional the UIKit presentation can bind to. Setting `nil`
    /// dismisses that level and everything above it.
    subscript(modalAt level: Int) -> ModalNavigator? {
        get { modals.indices.contains(level) ? modals[level] : nil }
        set {
            if newValue == nil, modals.count > level {
                modals.removeSubrange(level...)
            }
        }
    }
}

/// A root screen listening for its module's deep links, and the stack it subscribed on.
private struct RootSubscriber {
    let target: NavigationTarget
    let stack: StackNavigator
    /// Whether the screen was its stack's root when it subscribed. Only roots receive deep links: a
    /// deep link lands on a fresh stack, so screens pushed above the root are on their way out.
    let isRoot: Bool
    let continuation: AsyncStream<NavigationRequest>.Continuation

    func receives(_ target: NavigationTarget, on stack: StackNavigator) -> Bool {
        isRoot && self.target == target && self.stack === stack
    }
}

/// A deep link waiting for its stack's root to subscribe.
private struct PendingRequest {
    let request: NavigationRequest
    let stack: StackNavigator
}

/// Runs `work` once nothing is presented over `controller`'s stack. SwiftUI presents a screen's
/// alerts from a container (often the window's root), so the whole window is checked, skipping
/// presentations that hold the stack itself (the modal it lives in). An alert that is up and not
/// leaving — its state already gone — is closed. Checked every 50 ms; after about two seconds `work`
/// runs regardless. Without a window (unit tests) `work` runs right away.
@MainActor
private func whenUncovered(_ controller: UIViewController?, attempt: Int = 0, _ work: @escaping @MainActor () -> Void) {
    guard let controller, attempt < 40, let covering = presentation(covering: controller) else { return work() }
    if !(covering is UINavigationController), covering.transitionCoordinator == nil, !covering.isBeingDismissed {
        covering.presentingViewController?.dismiss(animated: true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
        whenUncovered(controller, attempt: attempt + 1, work)
    }
}

/// The first presentation in `controller`'s window that doesn't contain `controller`.
@MainActor
private func presentation(covering controller: UIViewController) -> UIViewController? {
    var presented = controller.view.window?.rootViewController?.presentedViewController
    while let candidate = presented {
        if !controller.isInside(candidate) { return candidate }
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
