import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract
import ScreenCNavigationContract
import ScreenDNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import IssuesDomain

/// The list owns its detail's state (`@Presents` + `.ifLet`) and pushes the detail through the
/// navigator in the same breath; the screen comes from a store scoped from the list's.
@MainActor
@Suite("Issues list", .serialized)
struct IssuesListTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeStore(_ navigator: NavigatorSpy) -> TestStoreOf<IssuesList> {
        withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.uuid = .incrementing
            $0.date = .constant(Self.now)
            $0.navigator = navigator
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            return TestStore(initialState: IssuesList.State()) { IssuesList() }
        }
    }

    @Test("Tapping a row sets the detail state and pushes its request; the reducer does nothing else")
    func tapPushes() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let issue = store.state.issues[1]

        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }
        await store.finish()
        #expect(navigator.pushed == [NavigationRequest(IssuesNavigationContract.Route.listDetails(id: issue.id.uuidString))])

        // Leaving arrives as the child's `.dismiss` (sent by `NavigationContext.child`), handled by `.ifLet`.
        await store.send(.detail(.dismiss)) {
            $0.detail = nil
        }
    }

    @Test("The detail's edits write through the shared array, with nothing sent back")
    func editsWriteThrough() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let issue = store.state.issues[0]
        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }

        await store.send(.detail(.presented(.titleChanged("Re-commissioning")))) {
            $0.$issues.withLock { $0[id: issue.id]?.title = "Re-commissioning" }
        }
        #expect(store.state.issues[id: issue.id]?.title == "Re-commissioning")
        #expect(navigator.sent.isEmpty)
        await store.finish()
    }

    @Test("Delete clears the state, removes the issue and pops")
    func deleteClearsAndPops() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let issue = store.state.issues[2]
        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }

        await store.send(.detail(.presented(.delegate(.deleteRequested)))) {
            $0.detail = nil
            $0.$issues.withLock { _ = $0.remove(id: issue.id) }
        }
        await store.finish()
        #expect(navigator.pops == 1)
        #expect(store.state.issues[id: issue.id] == nil)
    }

    @Test("Add appends a draft issue and opens it as the list's child")
    func addOpensNewIssue() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let new = IssuesDomain.Issue(id: UUID(0), status: .draft, createdAt: Self.now)

        await store.send(.addIssueTapped) {
            $0.$issues.withLock { $0.append(new) }
            $0.detail = IssuesDetail.State(issue: Shared(value: new))
        }
        await store.finish()
        #expect(navigator.pushed == [Issues.detailRequest(for: new)])
    }

    @Test("Swipe-delete removes the rows and pushes nothing")
    func swipeDeleteRemovesRows() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let removed = [store.state.issues[0].id, store.state.issues[2].id]

        await store.send(.deleteIssues([0, 2])) {
            $0.$issues.withLock { $0.remove(atOffsets: [0, 2]) }
        }
        #expect(removed.allSatisfy { store.state.issues[id: $0] == nil })
        #expect(navigator.pushed.isEmpty)
    }

    @Test("The header's Push and Present links send their request", arguments: [
        NavigationRequest(IssuesNavigationContract.Route.list),
        NavigationRequest(ScreenBNavigationContract.Route.home),
        NavigationRequest(ScreenCNavigationContract.Route.home),
        NavigationRequest(ScreenDNavigationContract.Route.home),
    ])
    func headerLinks(request: NavigationRequest) async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)

        await store.send(.pushTapped(request))
        await store.send(.presentTapped(request))
        await store.finish()
        #expect(navigator.pushed == [request])
        #expect(navigator.presented == [request])
    }

    @Test("Random issue pushes the random-issue request and keeps no detail state")
    func randomIssuePushes() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)

        await store.send(.randomIssueTapped)
        await store.finish()
        #expect(navigator.pushed == [NavigationRequest(IssuesNavigationContract.Route.random)])
    }

    @Test("A deep link opens the issue like a tap; an unknown issue leaves the list alone")
    func deepLinks() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let issue = store.state.issues[3]
        await store.send(.incomingRequest(NavigationRequest(IssuesNavigationContract.Route.open(id: UUID().uuidString))))
        await store.send(.incomingRequest(NavigationRequest(IssuesNavigationContract.Route.open(id: "not-a-uuid"))))

        await store.send(.incomingRequest(NavigationRequest(IssuesNavigationContract.Route.open(id: issue.id.uuidString)))) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }
        await store.finish()
        #expect(navigator.pushed == [Issues.detailRequest(for: issue)])
    }
}

/// The Issues deep-link grammar, and which links the list at the tab's root receives.
@MainActor
@Suite("Issues deep links")
struct IssuesDeepLinkTests {
    private let registration = Issues.navigationRegistration

    private func route(path: [String] = [], query: [String: String] = [:]) -> IssuesNavigationContract.Route? {
        registration.deepLink(DeepLink(target: .issues, path: path, query: query))?.route(as: IssuesNavigationContract.Route.self)
    }

    @Test("`issues` is the list, `issues/<id>` the issue, `?action=screenCContext` Screen C; anything else is nil")
    func grammar() {
        #expect(route() == .list)
        #expect(route(path: ["abc"]) == .open(id: "abc"))
        #expect(route(query: ["action": "screenCContext"]) == .screenCContext)
        #expect(route(query: ["action": ""]) == nil)
        #expect(route(query: ["action": "unknown"]) == nil)
    }

    @Test("Linked issues and the Screen C action go to the root list; the list itself is pushed")
    func toRoot() {
        #expect(registration.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.open(id: "abc"))))
        #expect(registration.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.screenCContext)))
        #expect(!registration.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.list)))
    }
}

/// The Issues registration's resolver builds the list's detail from the list's store, found through
/// `NavigationContext.parent`, and clears the list's state when the detail's entry leaves.
@MainActor
@Suite("Issues list · resolved detail", .serialized)
struct IssuesListResolverTests {
    private let navigator = NavigatorSpy()
    private let store: StoreOf<IssuesList>
    private let list: IssuesListHostingController
    /// What the resolver asked to run when the entry leaves.
    private let leaves = LeaveRecorder()

    init() {
        let navigator = navigator
        (store, list) = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = navigator
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let store = Store(initialState: IssuesList.State()) { IssuesList() }
            return (store, IssuesListHostingController(store: store))
        }
    }

    /// Resolves `request` through the Issues registration, as if pushed from `parent`.
    private func resolve(_ request: NavigationRequest, from parent: UIViewController?) throws -> UIViewController {
        let leaves = leaves
        return try Issues.navigationRegistration.resolver(
            request,
            NavigationContext(navigator: navigator, parent: parent, onLeave: { leaves.actions.append($0) })
        )
    }

    @Test("The tab root is the list, and the picker is the list in picker mode")
    func listResolvesList() throws {
        #expect(try resolve(NavigationRequest(IssuesNavigationContract.Route.list), from: nil) is IssuesListHostingController)
        let picker = try #require(try resolve(NavigationRequest(IssuesNavigationContract.Route.pick), from: nil) as? IssuesListHostingController)
        #expect(picker.store.isPicker)
    }

    @Test("Pushed from the list, the detail is built from the list's scoped store")
    func buildsFromParentStore() throws {
        let issue = store.issues[0]
        store.send(.issueTapped(issue.id))

        #expect(try resolve(Issues.detailRequest(for: issue), from: list) is UIHostingController<IssuesDetailView>)
        #expect(leaves.actions.count == 1)
    }

    @Test("Without the list as parent, or without matching state, it's a bug: reported, with a placeholder")
    func misuseShowsPlaceholder() throws {
        let issue = store.issues[0]
        withKnownIssue {
            let screen = try resolve(Issues.detailRequest(for: issue), from: list)
            #expect(!(screen is UIHostingController<IssuesDetailView>))
        }
        store.send(.issueTapped(issue.id))
        withKnownIssue {
            let screen = try resolve(Issues.detailRequest(for: issue), from: UIViewController())
            #expect(!(screen is UIHostingController<IssuesDetailView>))
        }
        #expect(leaves.actions.isEmpty)
    }

    @Test("The entry leaving (back, swipe, reset) clears the list's detail state")
    func leaveClearsState() throws {
        let issue = store.issues[0]
        store.send(.issueTapped(issue.id))
        _ = try resolve(Issues.detailRequest(for: issue), from: list)

        let leave = try #require(leaves.actions.first)
        leave()
        #expect(store.detail == nil)
    }

    @Test("Leaving after the list cleared the state itself (delete) sends nothing")
    func leaveAfterDeleteIsNoOp() throws {
        let issue = store.issues[0]
        store.send(.issueTapped(issue.id))
        _ = try resolve(Issues.detailRequest(for: issue), from: list)

        store.send(.detail(.presented(.delegate(.deleteRequested))))
        #expect(store.detail == nil)
        // A `.dismiss` now would make `.ifLet` report an action for absent state, failing the test.
        let leave = try #require(leaves.actions.first)
        leave()
        #expect(store.detail == nil)
    }

    @Test("An old detail leaving doesn't clear a newer one")
    func oldLeaveKeepsNewChild() throws {
        let first = store.issues[0]
        let second = store.issues[1]
        store.send(.issueTapped(first.id))
        _ = try resolve(Issues.detailRequest(for: first), from: list)

        store.send(.issueTapped(second.id))
        let leave = try #require(leaves.actions.first)
        leave()
        #expect(store.detail?.issue.id == second.id)
    }

    @Test("`.open` from another module is a detail that saves on its own, not the list's child")
    func openIsStandalone() throws {
        let screen = try resolve(NavigationRequest(IssuesNavigationContract.Route.open(id: store.issues[0].id.uuidString)), from: nil)
        #expect(screen is UIHostingController<IssuesDetailView>)
        #expect(leaves.actions.isEmpty)
    }
}

/// Collects `NavigationContext.onLeave` actions.
@MainActor
private final class LeaveRecorder {
    var actions: [@MainActor () -> Void] = []
}
