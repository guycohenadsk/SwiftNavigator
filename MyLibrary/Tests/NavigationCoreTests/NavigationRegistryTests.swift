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
    func performedActions(for target: NavigationTarget) -> AsyncStream<String> { AsyncStream { $0.finish() } }
    func push(local request: NavigationRequest, from origin: UIViewController, screen: @escaping @MainActor () -> UIViewController, onDismiss: @escaping @MainActor () -> Void) -> NavigationEntry.ID { NavigationEntry.ID() }
    func remove(_ id: NavigationEntry.ID) {}
}

@MainActor
private func registration(_ target: NavigationTarget) -> NavigationRegistration {
    NavigationRegistration(target: target) { request, _ in
        let controller = UIViewController()
        controller.title = request.target.rawValue
        return controller
    }
}

@MainActor
@Suite("NavigationRegistry")
struct NavigationRegistryTests {
    @Test("Dispatches to the registration that owns the target")
    func dispatch() throws {
        let registry = NavigationRegistry()
        try registry.register(registration(.issues))
        try registry.register(registration(.screenB))
        let controller = try registry.resolve(NavigationRequest(intent: .browse(.screenB)), navigator: InertNavigator())
        #expect(controller.title == "screenB")
    }

    @Test("Registering a target twice throws")
    func duplicate() throws {
        let registry = NavigationRegistry()
        try registry.register(registration(.issues))
        #expect(throws: NavigationError.duplicateRegistration(.issues)) {
            try registry.register(registration(.issues))
        }
    }

    @Test("Resolving an unregistered target throws")
    func unregistered() {
        #expect(throws: NavigationError.unregisteredTarget(.screenD)) {
            try NavigationRegistry().resolve(NavigationRequest(intent: .browse(.screenD)), navigator: InertNavigator())
        }
    }
}
