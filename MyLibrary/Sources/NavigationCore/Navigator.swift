public typealias NavigationResultHandler = @MainActor @Sendable (NavigationResult) -> Void

/// The only navigation seam a feature depends on. Features describe where to go with a
/// `NavigationRequest`; they never import each other or the registry.
@MainActor
public protocol Navigator: Sendable {
    /// Pushes onto the current stack. `onResult` gets any `.message` updates, then one final result.
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?)
    /// Presents in a new modal stack. `onResult` gets any `.message` updates, then one final result.
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?)
    /// Called by the top screen: sends an update to whoever opened it, and stays on screen.
    func send(_ result: NavigationResult)
    /// Called by the top screen: removes it and hands `result` to whoever opened it.
    func complete(with result: NavigationResult)
    func pop()
    func popToRoot()
    func dismiss()
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

    private func finalResult(of results: AsyncStream<NavigationResult>) async -> NavigationResult {
        for await result in results where result.isFinal {
            return result
        }
        return .dismissed
    }
}
