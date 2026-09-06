import AppRoutes
import ComposableArchitecture

extension DependencyValues {
    public var navigator: Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

private enum NavigatorKey: DependencyKey {
    static let liveValue: Navigator = UnimplementedNavigator()
    static let testValue: Navigator = UnimplementedNavigator()
}

/// Installed only if AppComposition forgets to call `prepareDependencies` at startup.
private struct UnimplementedNavigator: Navigator {
    func push(_ route: Route) {
        assertionFailure("Navigated to \(route) before AppComposition installed a live Navigator.")
    }

    func pop() {
        assertionFailure("Popped before AppComposition installed a live Navigator.")
    }

    func popToRoot() {
        assertionFailure("Popped to root before AppComposition installed a live Navigator.")
    }

    func present(_ route: Route) {
        assertionFailure("Presented \(route) before AppComposition installed a live Navigator.")
    }

    func dismiss() {
        assertionFailure("Dismissed before AppComposition installed a live Navigator.")
    }
}
