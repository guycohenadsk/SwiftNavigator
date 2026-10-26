import NavigationCore

/// Records what a screen asks of the navigator, and keeps the handlers of its pushes so a test can
/// play the pushed screen's side: send it outputs, or end it with `.dismissed`.
@MainActor
final class NavigatorSpy: Navigator {
    private(set) var pushed: [NavigationRequest] = []
    private(set) var pushHandlers: [NavigationResultHandler] = []
    private(set) var sent: [NavigationResult] = []
    private(set) var completed: [NavigationResult] = []
    private(set) var pops = 0

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        pushed.append(request)
        if let onResult { pushHandlers.append(onResult) }
    }

    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) { sent.append(result) }
    func complete(with result: NavigationResult) { completed.append(result) }
    func pop() { pops += 1 }
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { $0.finish() } }

    /// Waits until the reducer's effect has pushed `count` screens.
    func waitForPushes(_ count: Int = 1) async {
        while pushHandlers.count < count { await Task.yield() }
    }

    /// Plays the last pushed screen sending `output` back to whoever pushed it.
    func reply(_ output: some Hashable & Sendable) {
        pushHandlers.last?(.output(NavigationOutput(output)))
    }

    /// Plays the last pushed screen leaving.
    func dismissPushed() {
        pushHandlers.last?(.dismissed)
    }

    /// Plays the screen pushed `index`-th leaving.
    func dismissPushed(at index: Int) {
        pushHandlers[index](.dismissed)
    }
}
