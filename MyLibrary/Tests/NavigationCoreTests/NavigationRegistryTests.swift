import NavigationCore
import Testing
import UIKit

@MainActor
private final class InertNavigator: Navigator {
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { $0.finish() } }
}

private enum IssueRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case list
}

private enum BRoute: NavigationRoute {
    static let target = NavigationTarget.screenB
    case home
    case b2
}

@MainActor
private func issuesRegistration() -> NavigationRegistration {
    NavigationRegistration(IssueRoute.self) { _, _ in
        let controller = UIViewController()
        controller.title = "issues"
        return controller
    }
}

@MainActor
private func bRegistration() -> NavigationRegistration {
    NavigationRegistration(BRoute.self) { route, _ in
        let controller = UIViewController()
        controller.title = route == .home ? "home" : "b2"
        return controller
    }
}

@MainActor
@Suite("NavigationRegistry")
struct NavigationRegistryTests {
    @Test("Dispatches to the registration that owns the target, with the typed route")
    func dispatch() throws {
        let registry = NavigationRegistry()
        try registry.register(issuesRegistration())
        try registry.register(bRegistration())
        #expect(try registry.resolve(NavigationRequest(BRoute.b2), navigator: InertNavigator()).title == "b2")
        #expect(try registry.resolve(NavigationRequest(IssueRoute.list), navigator: InertNavigator()).title == "issues")
        #expect(registry.registeredTargets == [.issues, .screenB])
    }

    @Test("A request of another route type for the same target is wrongTarget")
    func wrongTarget() throws {
        // Declares itself as `.screenB` but is not BRoute.
        enum ImpostorRoute: NavigationRoute {
            static let target = NavigationTarget.screenB
            case home
        }
        let registry = NavigationRegistry()
        try registry.register(bRegistration())
        #expect(throws: NavigationError.wrongTarget) {
            try registry.resolve(NavigationRequest(ImpostorRoute.home), navigator: InertNavigator())
        }
    }

    @Test("Registering a target twice throws")
    func duplicate() throws {
        let registry = NavigationRegistry()
        try registry.register(issuesRegistration())
        #expect(throws: NavigationError.duplicateRegistration(.issues)) {
            try registry.register(issuesRegistration())
        }
    }

    @Test("Resolving an unregistered target throws")
    func unregistered() {
        #expect(throws: NavigationError.unregisteredTarget(.screenD)) {
            try NavigationRegistry().resolve(NavigationRequest(IssueRouteD.home), navigator: InertNavigator())
        }
    }
}

private enum IssueRouteD: NavigationRoute {
    static let target = NavigationTarget.screenD
    case home
}
