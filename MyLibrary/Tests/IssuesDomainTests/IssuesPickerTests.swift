import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import Testing

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
    @Test("Every message Screen C sends lands in the header; leaving Screen C ends the effect")
    func messagesReachHeader() async {
        let spy = CompletionSpy()
        let store = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = spy
        } operation: {
            TestStore(initialState: IssuesList.State()) { IssuesList() }
        }
        store.exhaustivity = .off   // the header is shared state written by the effect

        await store.send(.pushScreenCWithContextTapped)
        while spy.pushedHandler == nil { await Task.yield() }
        #expect(spy.pushed == [NavigationRequest(intent: .compose(.screenC, prompt: "I have been pushed from the issues list"))])

        spy.pushedHandler?(.message("Hello"))
        spy.pushedHandler?(.message("Hello again"))
        spy.pushedHandler?(.dismissed)
        await store.finish()

        #expect(store.state.screenCText == "Hello again")
    }

    @Test("The deep-link action runs the same flow and fills the same header")
    func deepLinkActionFillsHeader() async {
        let spy = CompletionSpy()
        await withDependencies {
            $0.navigator = spy
        } operation: {
            @Shared(.screenCText) var screenCText
            let flow = Task { await Issues.pushScreenCWithContext(navigator: spy) }
            while spy.pushedHandler == nil { await Task.yield() }

            spy.pushedHandler?(.message("From a link"))
            spy.pushedHandler?(.dismissed)
            await flow.value

            #expect(screenCText == "From a link")
        }
    }
}
