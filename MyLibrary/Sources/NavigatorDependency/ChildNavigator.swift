import ComposableArchitecture
import NavigationCore
import UIKit

/// How a parent shows one of its own children.
public enum ChildPresentation: Hashable, Sendable {
    case push
    case present
}

/// One call a reducer made to its `ChildNavigator`.
public struct ChildPush: Hashable, Sendable {
    public let request: NavigationRequest
    public let presentation: ChildPresentation

    public init(_ request: NavigationRequest, _ presentation: ChildPresentation = .push) {
        self.request = request
        self.presentation = presentation
    }
}

/// A screen's navigator for its own children — the reducer says *when* and *how* a child appears,
/// the screen's controller says *what* to build from the parent's state (`childDestination`).
///
/// The parent keeps owning the child's state: a reducer sets it, then pushes it here.
/// ```swift
/// state.detail = IssuesDetail.State(issue: issue)
/// return .run { _ in await childNavigator.push(.open(ref)) }
/// ```
/// Each screen's store gets its own instance (`$0.childNavigator = ChildNavigator()` when the
/// store is built), shared with the controller that binds it.
///
/// Leaving is still driven by state: when the child leaves (back, swipe, deep-link reset) its state
/// is cleared, and when the parent clears the state the child's entry is removed.
@MainActor
public final class ChildNavigator: Sendable {
    enum Mode {
        /// The dependency's default: a store that wasn't given its own navigator.
        case unset
        /// Records pushes only, for reducer tests.
        case recording
        /// Bound to a screen's controller.
        case live
    }

    let mode: Mode
    /// How long a child's state may wait for its push before that's reported. `nil` turns the
    /// check off; tests call `reportMissingPushes()` instead.
    var missingPushGrace: Duration? = .seconds(1)
    /// Every push the reducer made, in order.
    public private(set) var history: [ChildPush] = []
    /// The children the controller declared: each takes a push it matches, and reports whether it
    /// did.
    var destinations: [UUID: @MainActor (ChildPush) -> Bool] = [:]
    /// Each destination's check for state that was set but never pushed.
    var missingPushChecks: [UUID: @MainActor () -> NavigationRequest?] = [:]

    public nonisolated init() {
        self.mode = .live
    }

    nonisolated init(mode: Mode) {
        self.mode = mode
    }

    /// A navigator that only records pushes — for reducer tests that assert what was pushed.
    public nonisolated static func recording() -> ChildNavigator {
        ChildNavigator(mode: .recording)
    }

    /// Shows the child whose state names `request`. The state must already be set: a push that no
    /// child state matches is reported and ignored.
    public func push(_ request: NavigationRequest, as presentation: ChildPresentation = .push) {
        let push = ChildPush(request, presentation)
        history.append(push)
        switch mode {
        case .unset:
            reportIssue("""
                Pushed \(request) through a ChildNavigator the store wasn't given. Build the \
                screen's store with "withDependencies: { $0.childNavigator = children }" and bind \
                the same instance with "childDestination".
                """)
        case .recording:
            break
        case .live:
            for take in destinations.values where take(push) { return }
            reportIssue("""
                Pushed \(request), but no child state matches it. Set the child's state before \
                pushing it.
                """)
        }
    }

    /// Reports every child whose state is set but was never pushed.
    public func reportMissingPushes() {
        for check in missingPushChecks.values {
            if let request = check() {
                reportIssue("""
                    Child state for \(request) is set, but it was never pushed. Push it with \
                    "childNavigator.push(_:)" in the same action that sets the state.
                    """)
            }
        }
    }
}

extension DependencyValues {
    /// The current screen's navigator for its own children. See `ChildNavigator`.
    public var childNavigator: ChildNavigator {
        get { self[ChildNavigatorKey.self] }
        set { self[ChildNavigatorKey.self] = newValue }
    }
}

private enum ChildNavigatorKey: DependencyKey {
    static let liveValue = ChildNavigator(mode: .unset)
    static let testValue = ChildNavigator(mode: .recording)
}
