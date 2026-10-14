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

    @Test("perform runs the named action of the target's module")
    func performRunsAction() throws {
        var ran: [String] = []
        let registry = NavigationRegistry()
        try registry.register(NavigationRegistration(
            target: .issues,
            actions: ["go": { _ in ran.append("go") }],
            resolver: { _, _ in UIViewController() }
        ))

        try registry.perform(NavigationRequest(intent: .perform(.issues, action: "go")), navigator: InertNavigator())

        #expect(ran == ["go"])
    }

    @Test("perform rejects unknown actions and non-perform requests")
    func performRejects() throws {
        let registry = NavigationRegistry()
        try registry.register(registration(.issues))
        #expect(throws: NavigationError.unsupportedIntent) {
            try registry.perform(NavigationRequest(intent: .perform(.issues, action: "nope")), navigator: InertNavigator())
        }
        #expect(throws: NavigationError.unsupportedIntent) {
            try registry.perform(NavigationRequest(intent: .browse(.issues)), navigator: InertNavigator())
        }
        #expect(throws: NavigationError.unregisteredTarget(.screenB)) {
            try registry.perform(NavigationRequest(intent: .perform(.screenB, action: "go")), navigator: InertNavigator())
        }
    }
}
