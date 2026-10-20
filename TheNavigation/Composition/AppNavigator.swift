import Foundation
import NavigationCore
import Observation

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
                handlers.removeValue(forKey: id)?(.dismissed)
            }
        }
    }
    @ObservationIgnored private var handlers: [UUID: NavigationResultHandler] = [:]

    func push(_ entry: NavigationEntry, onResult: NavigationResultHandler?) {
        handlers[entry.id] = onResult
        path.append(entry)
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
    /// Who listens for deep-link actions: a target, and the stack whose root screen subscribed.
    @ObservationIgnored private var actionSubscribers: [UUID: ActionSubscriber] = [:]
    /// Deep-link actions that landed before their stack's root subscribed.
    @ObservationIgnored private var pendingActions: [PendingAction] = []

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

    func pop() { _ = current.path.popLast() }
    func popToRoot() { current.path.removeAll() }
    func dismiss() { _ = modals.popLast() }

    func performedActions(for target: NavigationTarget) -> AsyncStream<String> {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let id = UUID()
        let subscriber = ActionSubscriber(target: target, stack: current, isRoot: current.path.isEmpty, continuation: continuation)
        actionSubscribers[id] = subscriber
        continuation.onTermination = { _ in
            Task { @MainActor [weak self] in self?.actionSubscribers[id] = nil }
        }
        pendingActions.removeAll { pending in
            guard subscriber.receives(pending.target, on: pending.stack) else { return false }
            continuation.yield(pending.action)
            return true
        }
        return stream
    }

    /// Lands a deep link: dismiss modals, switch to the tab whose root is that module (if any) on a
    /// fresh stack, then push the request — unless that tab's root already is the request, or the
    /// request asks the module to run one of its actions (`.perform`), which goes to the stack's
    /// root screen through `performedActions(for:)`.
    func open(deepLink request: NavigationRequest) {
        modals = []
        if let tab = tabRoots.firstIndex(where: { $0.target == request.target }) {
            tabIndex = tab
            tabs[tab].path = []
            if tabRoots[tab] == request { return }
        }
        if case let .perform(target, action) = request.intent {
            deliver(action, to: target, on: current)
        } else {
            push(request)
        }
    }

    /// Hands `action` to the root screen of `stack` listening for `target`, or holds it until one
    /// subscribes.
    private func deliver(_ action: String, to target: NavigationTarget, on stack: StackNavigator) {
        if let subscriber = actionSubscribers.values.first(where: { $0.receives(target, on: stack) }) {
            subscriber.continuation.yield(action)
        } else {
            pendingActions.append(PendingAction(target: target, stack: stack, action: action))
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

/// A screen listening for its module's deep-link actions, and the stack it subscribed on.
private struct ActionSubscriber {
    let target: NavigationTarget
    let stack: StackNavigator
    /// Whether the screen was its stack's root when it subscribed. Only roots receive actions: a
    /// deep link lands on a fresh stack, so screens pushed above the root are on their way out.
    let isRoot: Bool
    let continuation: AsyncStream<String>.Continuation

    func receives(_ target: NavigationTarget, on stack: StackNavigator) -> Bool {
        isRoot && self.target == target && self.stack === stack
    }
}

/// A deep-link action waiting for its stack's root to subscribe.
private struct PendingAction {
    let target: NavigationTarget
    let stack: StackNavigator
    let action: String
}
