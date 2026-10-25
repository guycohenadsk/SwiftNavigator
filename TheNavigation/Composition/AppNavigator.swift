import Foundation
import NavigationCore
import Observation
import UIKit

/// One back stack — a tab's or a modal's. The same shape as navigation_contract's AppNavigator: a
/// path, the result handlers of its entries, and a `didSet` that reports `.dismissed` for every
/// entry that disappears however it disappeared (pop, swipe-back, reset).
@MainActor
@Observable
final class StackNavigator {
    var path: [NavigationEntry] = [] {
        didSet {
            let removedIDs = Set(oldValue.map(\.id)).subtracting(path.map(\.id))
            for id in removedIDs {
                localScreens[id] = nil
                handlers.removeValue(forKey: id)?(.dismissed)
            }
        }
    }
    @ObservationIgnored private var handlers: [UUID: NavigationResultHandler] = [:]
    /// Builders of entries a parent pushed with `push(local:…)`; everything else goes through the
    /// registry.
    @ObservationIgnored private var localScreens: [UUID: @MainActor () -> UIViewController] = [:]
    /// The UIKit stack bound to `path`, so a parent screen's pushes can find their stack.
    @ObservationIgnored weak var controller: UINavigationController?

    func push(_ entry: NavigationEntry, onResult: NavigationResultHandler?) {
        handlers[entry.id] = onResult
        path.append(entry)
    }

    func push(local entry: NavigationEntry, screen: @escaping @MainActor () -> UIViewController, onDismiss: @escaping @MainActor () -> Void) {
        localScreens[entry.id] = screen
        // Any final result means the entry is gone — `.dismissed`, or the child completing itself.
        push(entry) { result in
            if result.isFinal { onDismiss() }
        }
    }

    /// The screen of a local entry, or `nil` for entries the registry resolves.
    func localScreen(for id: UUID) -> UIViewController? {
        localScreens[id]?()
    }

    /// Removes `id` and everything above it. `id`'s own handler is dropped first — its parent asked
    /// for this — while entries above still report `.dismissed`. Returns whether `id` was here.
    @discardableResult
    func remove(_ id: UUID) -> Bool {
        guard let index = path.firstIndex(where: { $0.id == id }) else { return false }
        handlers[id] = nil
        path.removeSubrange(index...)
        return true
    }

    /// Hands an update to whoever pushed the top entry, leaving it in place.
    func send(_ result: NavigationResult) {
        guard let last = path.last else { return }
        handlers[last.id]?(result)
    }

    /// Removes the top entry and hands `result` to whoever pushed it.
    func complete(with result: NavigationResult) {
        guard let last = path.last else { return }
        let handler = handlers.removeValue(forKey: last.id)
        path.removeLast()
        handler?(result)
    }
}

/// One modal level: the entry it was presented with, and its own back stack.
@MainActor
@Observable
final class ModalNavigator: Identifiable {
    let root: NavigationEntry
    let stack = StackNavigator()
    @ObservationIgnored var onResult: NavigationResultHandler?
    /// The root's builder when a parent presented it (`present(local:…)`); otherwise the registry
    /// resolves `root.request`.
    @ObservationIgnored let localScreen: (@MainActor () -> UIViewController)?
    var id: UUID { root.id }

    init(root: NavigationEntry, onResult: NavigationResultHandler?, localScreen: (@MainActor () -> UIViewController)? = nil) {
        self.root = root
        self.onResult = onResult
        self.localScreen = localScreen
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
    /// Whether a deep link goes to its module's root screen rather than being pushed. `.perform`
    /// always does; AppComposition adds what each registration declares (`deepLinksToRoot`).
    @ObservationIgnored var deepLinksToRoot: (NavigationRequest) -> Bool = { request in
        if case .perform = request.intent { true } else { false }
    }

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
    private var allStacks: [StackNavigator] { tabs + modals.map(\.stack) }

    /// The stack whose UIKit controller shows `origin`, so a parent's child lands next to it even if
    /// another stack is on top. Falls back to the current stack for a screen not yet on one.
    private func stack(holding origin: UIViewController) -> StackNavigator {
        let controller = origin.navigationController ?? origin as? UINavigationController
        return allStacks.first { $0.controller != nil && $0.controller === controller } ?? current
    }

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

    func push(
        local request: NavigationRequest,
        from origin: UIViewController,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        let entry = NavigationEntry(request: request)
        stack(holding: origin).push(local: entry, screen: screen, onDismiss: onDismiss)
        return entry.id
    }

    func present(
        local request: NavigationRequest,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        let entry = NavigationEntry(request: request)
        let modal = ModalNavigator(root: entry, onResult: { result in
            if result.isFinal { onDismiss() }
        }, localScreen: screen)
        modals.append(modal)
        return entry.id
    }

    func remove(_ id: NavigationEntry.ID) {
        if let index = modals.firstIndex(where: { $0.root.id == id }) {
            // Its parent asked for this: no onDismiss for it, while modals above still report.
            modals[index].onResult = nil
            modals.removeSubrange(index...)
            return
        }
        for stack in allStacks where stack.remove(id) { return }
    }

    func pop() { _ = current.path.popLast() }
    func popToRoot() { current.path.removeAll() }
    func dismiss() { _ = modals.popLast() }

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
    /// root screen handles it itself (`.perform`, or `deepLinksToRoot`), in which case it goes to
    /// that root through `incomingRequests(for:)`.
    func open(deepLink request: NavigationRequest) {
        modals = []
        if let tab = tabRoots.firstIndex(where: { $0.target == request.target }) {
            tabIndex = tab
            tabs[tab].path = []
            if tabRoots[tab] == request { return }
            if deepLinksToRoot(request) {
                deliver(request, on: tabs[tab])
                return
            }
        }
        if case .perform = request.intent {
            deliver(request, on: current)
        } else {
            push(request)
        }
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
