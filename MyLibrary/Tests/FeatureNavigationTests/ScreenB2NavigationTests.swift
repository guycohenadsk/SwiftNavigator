import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import ScreenBFeature

/// Records the local pushes Screen B makes through the navigator, and the entries it removes.
@MainActor
private final class LocalPushSpy: Navigator {
    struct LocalPush {
        let id: NavigationEntry.ID
        let request: NavigationRequest
        let screen: @MainActor () -> UIViewController
        let onDismiss: @MainActor () -> Void
    }

    private(set) var pushes: [LocalPush] = []
    private(set) var removed: [NavigationEntry.ID] = []

    func push(
        local request: NavigationRequest,
        from origin: UIViewController,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        let push = LocalPush(id: NavigationEntry.ID(), request: request, screen: screen, onDismiss: onDismiss)
        pushes.append(push)
        return push.id
    }

    func remove(_ id: NavigationEntry.ID) { removed.append(id) }

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { _ in } }
}

@MainActor
private func settle() async {
    for _ in 0..<20 { await Task.yield() }
}

/// Screen B2 travels through the navigator as Screen B's `.b2` entry; its state stays in Screen B.
@MainActor
@Suite("Screen B → B2 through the navigator")
struct ScreenB2NavigationTests {
    private let spy = LocalPushSpy()
    private let store: StoreOf<ScreenBFeature>
    private let controller: ScreenBHostingController

    init() {
        let spy = spy
        (store, controller) = withDependencies {
            $0.navigator = spy
        } operation: {
            let store = Store(initialState: ScreenBFeature.State()) { ScreenBFeature() }
            return (store, ScreenBHostingController(store: store))
        }
        controller.loadViewIfNeeded()
    }

    @Test("Pushing B2 sets Screen B's state and pushes a .screen(.screenB, \"b2\") entry")
    func pushes() async throws {
        store.send(.pushScreenB2Tapped)
        await settle()

        #expect(store.screenB2 != nil)
        let push = try #require(spy.pushes.first)
        #expect(spy.pushes.count == 1)
        #expect(push.request == NavigationRequest(intent: .screen(.screenB, name: "b2")))
        #expect(push.screen() is UIHostingController<ScreenB2View>)
    }

    @Test("Leaving B2 clears Screen B's state, and B2 can be pushed again")
    func dismissThenReopen() async throws {
        store.send(.pushScreenB2Tapped)
        await settle()

        try #require(spy.pushes.first).onDismiss()
        await settle()
        #expect(store.screenB2 == nil)

        store.send(.pushScreenB2Tapped)
        await settle()
        #expect(spy.pushes.count == 2)
        #expect(spy.removed.isEmpty)
    }
}
