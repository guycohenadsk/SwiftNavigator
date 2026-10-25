import UIKit

public typealias NavigationResultHandler = @MainActor @Sendable (NavigationResult) -> Void

/// The only navigation seam a feature depends on. Features describe where to go with a
/// `NavigationRequest`; they never import each other or the registry.
@MainActor
public protocol Navigator: Sendable {
    /// Pushes onto the current stack. `onResult` gets any `.output` updates, then one final result.
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?)
    /// Presents in a new modal stack. `onResult` gets any `.output` updates, then one final result.
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?)
    /// Called by the top screen: sends an update to whoever opened it, and stays on screen.
    func send(_ result: NavigationResult)
    /// Called by the top screen: removes it and hands `result` to whoever opened it.
    func complete(with result: NavigationResult)
    func pop()
    func popToRoot()
    func dismiss()
    /// Pushes a screen whose state its parent owns (an in-module child, e.g. Issues list → detail)
    /// onto the stack that holds `origin`, right on top. `request` names what it shows, so the entry
    /// is data like any other; `screen` builds it from the parent's state. `onDismiss` fires once,
    /// however the entry leaves — pop, swipe-back, deep-link reset, or an entry below it going —
    /// but not when the parent removes it with `remove(_:)`. Returns the entry's id.
    @discardableResult
    func push(
        local request: NavigationRequest,
        from origin: UIViewController,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID
    /// Presents a screen whose state its parent owns in a new modal stack, as an entry named
    /// `request`. `onDismiss` fires once, however the modal leaves — swipe-down, `dismiss()`, a deep
    /// link — but not when the parent removes it with `remove(_:)`. Returns the entry's id.
    @discardableResult
    func present(
        local request: NavigationRequest,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID
    /// Removes the entry `id` and everything pushed above it, wherever it is. Used by a parent
    /// whose child state went away. Does nothing if the entry is already gone.
    func remove(_ id: NavigationEntry.ID)
    /// Deep links for `target` that its root screen handles itself: `.perform` actions, and requests
    /// its registration sends to the root (`deepLinksToRoot`, e.g. Issues' `.open`, so a linked issue
    /// opens as a child of the list). Delivered to the screen at the root of the stack the link lands
    /// on. Subscribe once from that screen and turn each request into an action; a link that lands
    /// before anyone subscribes is held until then.
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest>
}

extension Navigator {
    public func push(_ request: NavigationRequest) {
        push(request, onResult: nil)
    }

    public func present(_ request: NavigationRequest) {
        present(request, onResult: nil)
    }

    /// Every result of a pushed screen — its updates, then the final one, which ends the stream.
    public func pushForResults(_ request: NavigationRequest) -> AsyncStream<NavigationResult> {
        results { push(request, onResult: $0) }
    }

    /// Every result of a presented screen — its updates, then the final one, which ends the stream.
    public func presentForResults(_ request: NavigationRequest) -> AsyncStream<NavigationResult> {
        results { present(request, onResult: $0) }
    }

    /// The typed updates of a pushed screen, e.g. `ScreenCNavigationContract.Output`. Ends when the
    /// screen leaves; final results and updates of another type are skipped.
    public func pushForOutputs<Output: Sendable>(_ request: NavigationRequest, as type: Output.Type) -> AsyncStream<Output> {
        outputs(as: type) { push(request, onResult: $0) }
    }

    /// The typed updates of a presented screen. Ends when the screen leaves.
    public func presentForOutputs<Output: Sendable>(_ request: NavigationRequest, as type: Output.Type) -> AsyncStream<Output> {
        outputs(as: type) { present(request, onResult: $0) }
    }

    /// The final result of a pushed screen, e.g. a picker's pick. Updates are skipped.
    public func pushForResult(_ request: NavigationRequest) async -> NavigationResult {
        await finalResult(of: pushForResults(request))
    }

    /// The final result of a presented screen, e.g. a picker's pick. Updates are skipped.
    public func presentForResult(_ request: NavigationRequest) async -> NavigationResult {
        await finalResult(of: presentForResults(request))
    }

    private func results(_ open: (@escaping NavigationResultHandler) -> Void) -> AsyncStream<NavigationResult> {
        let (stream, continuation) = AsyncStream<NavigationResult>.makeStream()
        open { result in
            continuation.yield(result)
            if result.isFinal { continuation.finish() }
        }
        return stream
    }

    private func outputs<Output: Sendable>(
        as type: Output.Type,
        _ open: (@escaping NavigationResultHandler) -> Void
    ) -> AsyncStream<Output> {
        let (stream, continuation) = AsyncStream<Output>.makeStream()
        open { result in
            if let output = result.output(as: type) { continuation.yield(output) }
            if result.isFinal { continuation.finish() }
        }
        return stream
    }

    private func finalResult(of results: AsyncStream<NavigationResult>) async -> NavigationResult {
        for await result in results where result.isFinal {
            return result
        }
        return .dismissed
    }
}
