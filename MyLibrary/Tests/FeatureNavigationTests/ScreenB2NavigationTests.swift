import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import ScreenBFeature

/// Records the requests Screen B pushes.
@MainActor
private final class PushSpy: Navigator {
    private(set) var pushed: [NavigationRequest] = []

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) { pushed.append(request) }
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { _ in } }
}

/// Screen B2 is pushed as Screen B's `.b2` request and built by Screen B's registration; Screen B
/// keeps no state of it.
@MainActor
@Suite("Screen B → B2 through the navigator")
struct ScreenB2NavigationTests {
    @Test("Pushing B2 pushes a .screen(.screenB, \"b2\") request, and only that")
    func pushes() async {
        let spy = PushSpy()
        let store = TestStore(initialState: ScreenBFeature.State()) { ScreenBFeature() } withDependencies: {
            $0.navigator = spy
        }

        await store.send(.pushScreenB2Tapped)
        await store.finish()

        #expect(spy.pushed == [NavigationRequest(intent: .screen(.screenB, name: "b2"))])
    }

    @Test("Screen B's registration builds B2 from that request")
    func resolvesB2() throws {
        let controller = try ScreenB.navigationRegistration.resolver(ScreenBNavigationContract.request(for: .b2), NavigationContext(navigator: PushSpy()))
        #expect(controller is UIHostingController<ScreenB2View>)
    }
}
