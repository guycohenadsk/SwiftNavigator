import ComposableArchitecture
import NavigationCore

extension DependencyValues {
    public var navigator: any Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

private enum NavigatorKey: DependencyKey {
    static let liveValue: any Navigator = UnimplementedNavigator()
    static let testValue: any Navigator = UnimplementedNavigator()
}

/// Installed only if AppComposition forgets to call `prepareDependencies` at startup.
private struct UnimplementedNavigator: Navigator {
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        assertionFailure("Pushed \(request) before AppComposition installed a live Navigator.")
    }

    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        assertionFailure("Presented \(request) before AppComposition installed a live Navigator.")
    }

    func send(_ result: NavigationResult) {
        assertionFailure("Sent \(result) before AppComposition installed a live Navigator.")
    }

    func complete(with result: NavigationResult) {
        assertionFailure("Completed before AppComposition installed a live Navigator.")
    }

    func pop() {
        assertionFailure("Popped before AppComposition installed a live Navigator.")
    }

    func popToRoot() {
        assertionFailure("Popped to root before AppComposition installed a live Navigator.")
    }

    func dismiss() {
        assertionFailure("Dismissed before AppComposition installed a live Navigator.")
    }

    func performedActions(for target: NavigationTarget) -> AsyncStream<String> {
        assertionFailure("Subscribed to \(target)'s deep-link actions before AppComposition installed a live Navigator.")
        return AsyncStream { $0.finish() }
    }
}
