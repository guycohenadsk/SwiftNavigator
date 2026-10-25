import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import ScreenCNavigationContract
import Testing
import UIKit

@testable import IssuesDomain

@MainActor
private final class CompletionSpy: Navigator {
    private(set) var results: [NavigationResult] = []
    private(set) var pushed: [NavigationRequest] = []
    var pushedHandler: NavigationResultHandler?
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        pushed.append(request)
        pushedHandler = onResult
    }
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) { results.append(result) }
    func pop() {}
    func popToRoot() {}
    func dismiss() {}

    /// Feeds deep-link actions to whichever list subscribed.
    private(set) var actionContinuation: AsyncStream<NavigationRequest>.Continuation?
    func push(local request: NavigationRequest, from origin: UIViewController, screen: @escaping @MainActor () -> UIViewController, onDismiss: @escaping @MainActor () -> Void) -> NavigationEntry.ID { NavigationEntry.ID() }
    func present(local request: NavigationRequest, screen: @escaping @MainActor () -> UIViewController, onDismiss: @escaping @MainActor () -> Void) -> NavigationEntry.ID { NavigationEntry.ID() }
    func remove(_ id: NavigationEntry.ID) {}

    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> {
        let (stream, continuation) = AsyncStream<NavigationRequest>.makeStream()
        actionContinuation = continuation
        return stream
    }
}

@MainActor
@Suite("Issues picker", .serialized)
struct IssuesPickerTests {
    @Test("Tapping a row in picker mode completes with that issue instead of opening it")
    func pickCompletes() async throws {
        let spy = CompletionSpy()
        let store = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = spy
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            return TestStore(initialState: IssuesList.State(isPicker: true)) { IssuesList() }
        }
        let issue = try #require(store.state.issues.first)

        await store.send(.issueTapped(issue.id))
        await store.finish()

        #expect(spy.results == [.selectedEntity(EntityRef(target: .issues, id: issue.id.uuidString, title: issue.rowTitle))])
        #expect(store.state.detail == nil)
    }
}

@MainActor
@Suite("Issues list ⇄ Screen C context", .serialized)
struct IssuesScreenCContextTests {
    private func makeStore(_ spy: CompletionSpy, state: IssuesList.State = IssuesList.State()) -> TestStoreOf<IssuesList> {
        withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = spy
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            return TestStore(initialState: state) { IssuesList() }
        }
    }

    private func send(_ output: ScreenCNavigationContract.Output, to spy: CompletionSpy) {
        spy.pushedHandler?(.output(NavigationOutput(output)))
    }

    @Test("Every text Screen C sends arrives as a .screenC action; leaving Screen C ends the effect")
    func outputsArriveAsActions() async {
        let spy = CompletionSpy()
        let store = makeStore(spy)

        await store.send(.pushScreenCWithContextTapped)
        while spy.pushedHandler == nil { await Task.yield() }
        #expect(spy.pushed == [ScreenCNavigationContract.compose(prompt: "I have been pushed from the issues list")])

        send(.textSubmitted("Hello"), to: spy)
        await store.receive(\.screenC, .textSubmitted("Hello")) { $0.screenCText = "Hello" }
        send(.textSubmitted("Hello again"), to: spy)
        await store.receive(\.screenC, .textSubmitted("Hello again")) { $0.screenCText = "Hello again" }

        spy.pushedHandler?(.dismissed)
        await store.finish()
    }

    @Test("Outputs of another type are ignored")
    func foreignOutputsIgnored() async {
        let spy = CompletionSpy()
        let store = makeStore(spy)

        await store.send(.pushScreenCWithContextTapped)
        while spy.pushedHandler == nil { await Task.yield() }

        spy.pushedHandler?(.output(NavigationOutput("not a Screen C output")))
        spy.pushedHandler?(.dismissed)
        await store.finish()
    }

    @Test("The screenCContext deep-link action runs the same flow as the chip, in the same list")
    func deepLinkActionRunsFlow() async {
        let spy = CompletionSpy()
        let store = makeStore(spy)

        await store.send(.onAppear) { $0.isListeningForDeepLinks = true }
        while spy.actionContinuation == nil { await Task.yield() }
        await store.send(.onAppear)   // appearing again does not subscribe twice

        spy.actionContinuation?.yield(NavigationRequest(intent: .perform(.issues, action: Issues.screenCContextAction)))
        await store.receive(\.incomingRequest)
        while spy.pushedHandler == nil { await Task.yield() }
        #expect(spy.pushed == [ScreenCNavigationContract.compose(prompt: "I have been pushed from the issues list")])

        send(.textSubmitted("From a link"), to: spy)
        await store.receive(\.screenC, .textSubmitted("From a link")) { $0.screenCText = "From a link" }
        spy.pushedHandler?(.dismissed)

        spy.actionContinuation?.yield(NavigationRequest(intent: .perform(.issues, action: "unknown")))
        await store.receive(\.incomingRequest)
        spy.actionContinuation?.finish()
        await store.finish()
        #expect(spy.pushed.count == 1)
    }

    @Test("A linked issue opens as the list's own detail; an unknown one leaves the list alone")
    func deepLinkedIssueOpensInList() async throws {
        let spy = CompletionSpy()
        let store = makeStore(spy)
        @Shared(.issues) var issues
        let issue = try #require(issues.first)

        await store.send(.onAppear) { $0.isListeningForDeepLinks = true }
        while spy.actionContinuation == nil { await Task.yield() }

        spy.actionContinuation?.yield(NavigationRequest(intent: .open(EntityRef(target: .issues, id: "not-a-uuid", title: ""))))
        await store.receive(\.incomingRequest)
        spy.actionContinuation?.yield(NavigationRequest(intent: .open(EntityRef(target: .issues, id: UUID().uuidString, title: ""))))
        await store.receive(\.incomingRequest)

        spy.actionContinuation?.yield(NavigationRequest(intent: .open(Issues.ref(for: issue))))
        await store.receive(\.incomingRequest) {
            $0.detail = IssuesDetail.State(issue: Shared($0.$issues[id: issue.id])!)
        }

        spy.actionContinuation?.finish()
        await store.finish()
    }

    @Test("A picker does not listen for deep-link actions")
    func pickerIgnoresDeepLinks() async {
        let spy = CompletionSpy()
        let store = makeStore(spy, state: IssuesList.State(isPicker: true))
        await store.send(.onAppear)
        #expect(spy.actionContinuation == nil)
    }
}
