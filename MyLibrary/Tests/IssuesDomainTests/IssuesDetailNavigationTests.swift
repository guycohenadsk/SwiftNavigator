import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import ScreenCNavigationContract
import ScreenDNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import IssuesDomain

/// The detail as another module opens it (`.open`): nobody owns it, so it saves and deletes on its
/// own.
@MainActor
@Suite("Issue detail opened by another module", .serialized)
struct IssuesDetailNavigationTests {
    private let navigator = NavigatorSpy()

    /// The store, its issue, and the stored issues, which live in in-memory storage.
    private func makeStore() -> (TestStoreOf<IssueDetailScreen>, IssuesDomain.Issue, Shared<IdentifiedArrayOf<IssuesDomain.Issue>>) {
        let navigator = navigator
        return withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = navigator
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let issue = issues[0]
            let store = TestStore(initialState: IssueDetailScreen.State(issue: Shared($issues[id: issue.id])!)) {
                IssueDetailScreen()
            }
            return (store, issue, $issues)
        }
    }

    @Test("Its edits go straight to the stored issue, with nothing sent back")
    func savesItself() async {
        let (store, issue, issues) = makeStore()

        await store.send(.detail(.titleChanged("Renamed"))) {
            $0.detail.$issue.withLock { $0.title = "Renamed" }
        }
        await store.finish()

        #expect(navigator.sent.isEmpty)
        #expect(issues.wrappedValue[id: issue.id]?.title == "Renamed")
    }

    @Test("It deletes the issue itself, then closes")
    func deletesItself() async {
        let (store, issue, issues) = makeStore()
        store.exhaustivity = .off

        await store.send(.detail(.deleteButtonTapped))
        await store.send(.detail(.alert(.presented(.confirmDelete))))
        await store.receive(\.detail.delegate.deleteRequested)
        await store.finish()

        #expect(navigator.sent.isEmpty)
        #expect(navigator.completed == [.dismissed])
        #expect(issues.wrappedValue[id: issue.id] == nil)
    }

    @Test("The resolver builds it from `.open`, and a not-found screen for unknown ids")
    func resolverBuildsFromRequest() {
        withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let context = NavigationContext(navigator: navigator)
            let open = Issues.viewController(for: .open(id: issues[0].id.uuidString), context: context)
            let unknown = Issues.viewController(for: .open(id: UUID().uuidString), context: context)
            #expect(open is UIHostingController<IssuesDetailView>)
            #expect(!(unknown is UIHostingController<IssuesDetailView>))
        }
    }

    @Test("`.random` opens a stored issue picked with the random generator, standalone")
    func randomIssue() {
        let (screen, empty) = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.withRandomNumberGenerator = WithRandomNumberGenerator(ZeroGenerator())
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let context = NavigationContext(navigator: navigator)
            let screen = Issues.viewController(for: .random, context: context)
            $issues.withLock { $0 = [] }
            return (screen, Issues.viewController(for: .random, context: context))
        }
        var generator = ZeroGenerator()
        let expected = Issue.seed.randomElement(using: &generator)
        #expect((screen as? UIHostingController<IssuesDetailView>)?.rootView.store.issue.id == expected?.id)
        #expect(!(empty is UIHostingController<IssuesDetailView>))
    }
}

/// The detail's own links go through the navigator, wherever the detail was opened from.
@MainActor
@Suite("Issue detail links")
struct IssuesDetailLinksTests {
    @Test("Screen C is pushed, Screen D is presented as a sheet")
    func links() async {
        let navigator = NavigatorSpy()
        let store = TestStore(initialState: IssuesDetail.State(issue: Shared(value: Issue.seed[0]))) {
            IssuesDetail()
        } withDependencies: {
            $0.navigator = navigator
        }

        await store.send(.openScreenCTapped)
        await store.send(.openScreenDAsSheetTapped)
        await store.finish()
        #expect(navigator.pushed == [NavigationRequest(ScreenCNavigationContract.Route.home)])
        #expect(navigator.presented == [NavigationRequest(ScreenDNavigationContract.Route.home)])
    }
}

/// Always the same numbers, so a random pick is predictable.
private struct ZeroGenerator: RandomNumberGenerator, Sendable {
    mutating func next() -> UInt64 { 0 }
}
