import ComposableArchitecture
import NavigationCore
import IssuesNavigationContract
import NavigatorDependency
import ScreenDNavigationContract
import Testing

@testable import ScreenBFeature

/// Records what Screen B and B2 ask of the navigator, and keeps a presented screen's handler so a
/// test can play the picker answering.
@MainActor
private final class ScreenBNavigatorSpy: Navigator {
    private(set) var pushed: [NavigationRequest] = []
    private(set) var presented: [NavigationRequest] = []
    private(set) var presentHandler: NavigationResultHandler?

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) { pushed.append(request) }
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        presented.append(request)
        presentHandler = onResult
    }
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { _ in } }

    func waitForPresent() async {
        while presentHandler == nil { await Task.yield() }
    }
}

@MainActor
@Suite("Screen B")
struct ScreenBFeatureTests {
    private let spy = ScreenBNavigatorSpy()
    private let issue = EntityRef(
        id: "00000000-0000-0000-0000-000000000002",
        title: "#931 Plumbing riser leak",
        open: NavigationRequest(IssuesNavigationContract.Route.open(id: "00000000-0000-0000-0000-000000000002"))
    )

    private func makeStore() -> TestStoreOf<ScreenBFeature> {
        let spy = spy
        return TestStore(initialState: ScreenBFeature.State()) { ScreenBFeature() } withDependencies: {
            $0.navigator = spy
        }
    }

    @Test("Link an issue presents the Issues picker and keeps what it picks")
    func linkStoresPick() async {
        let store = makeStore()

        await store.send(.linkIssueTapped)
        await spy.waitForPresent()
        #expect(spy.presented == [NavigationRequest(IssuesNavigationContract.Route.pick)])

        spy.presentHandler?(.selectedEntity(issue))
        await store.receive(\.issueLinked, issue) { $0.linkedIssue = issue }
    }

    @Test("Dismissing the picker links nothing")
    func dismissLinksNothing() async {
        let store = makeStore()

        await store.send(.linkIssueTapped)
        await spy.waitForPresent()
        spy.presentHandler?(.dismissed)
        await store.finish()
        #expect(store.state.linkedIssue == nil)
    }

    @Test("Opening the linked issue pushes it as .open; without one it does nothing")
    func openLinkedIssue() async {
        let store = makeStore()

        await store.send(.openLinkedIssueTapped)
        await store.send(.issueLinked(issue)) { $0.linkedIssue = issue }
        await store.send(.openLinkedIssueTapped)
        await store.finish()
        #expect(spy.pushed == [NavigationRequest(IssuesNavigationContract.Route.open(id: issue.id))])
    }

    @Test("Issues and Screen D are pushed by target")
    func browseLinks() async {
        let store = makeStore()

        await store.send(.openIssuesTapped)
        await store.send(.openScreenDTapped)
        await store.finish()
        #expect(spy.pushed == [NavigationRequest(IssuesNavigationContract.Route.list), NavigationRequest(ScreenDNavigationContract.Route.home)])
    }
}

@MainActor
@Suite("Screen B2")
struct ScreenB2FeatureTests {
    @Test("Issues is pushed, Screen D is presented as a sheet")
    func links() async {
        let spy = ScreenBNavigatorSpy()
        let store = TestStore(initialState: ScreenB2Feature.State()) { ScreenB2Feature() } withDependencies: {
            $0.navigator = spy
        }

        await store.send(.openIssuesTapped)
        await store.send(.openScreenDAsSheetTapped)
        await store.finish()
        #expect(spy.pushed == [NavigationRequest(IssuesNavigationContract.Route.list)])
        #expect(spy.presented == [NavigationRequest(ScreenDNavigationContract.Route.home)])
    }
}
