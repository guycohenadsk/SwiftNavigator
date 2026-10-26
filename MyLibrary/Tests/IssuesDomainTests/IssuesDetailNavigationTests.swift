import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import SwiftUI
import Testing
import UIKit

@testable import IssuesDomain

/// The detail as the navigator builds it from a request: the list's own detail reports to the list
/// through outputs; a detail opened by another module saves and deletes on its own.
@MainActor
@Suite("Issue detail built from its request", .serialized)
struct IssuesDetailNavigationTests {
    private let navigator = NavigatorSpy()

    /// The store, its issue, and the stored issues, which live in in-memory storage.
    private func makeStore(reportsToOpener: Bool) -> (TestStoreOf<IssueDetailScreen>, IssuesDomain.Issue, Shared<IdentifiedArrayOf<IssuesDomain.Issue>>) {
        let navigator = navigator
        return withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = navigator
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let issue = issues[0]
            let shared = reportsToOpener ? Shared(value: issue) : Shared($issues[id: issue.id])!
            let store = TestStore(initialState: IssueDetailScreen.State(issue: shared, reportsToOpener: reportsToOpener)) {
                IssueDetailScreen()
            }
            return (store, issue, $issues)
        }
    }

    @Test("The list's detail works on a copy and sends every edit as an .edited output")
    func listDetailReportsEdits() async {
        let (store, issue, issues) = makeStore(reportsToOpener: true)

        var renamed = issue
        renamed.title = "Renamed"
        await store.send(.detail(.titleChanged("Renamed"))) {
            $0.detail.$issue.withLock { $0.title = "Renamed" }
            $0.reportedIssue = renamed
        }
        await store.finish()

        #expect(navigator.sent == [.output(NavigationOutput(IssuesDetail.Output.edited(renamed)))])
        #expect(issues.wrappedValue[id: issue.id]?.title == issue.title)
    }

    @Test("The list's detail asks the list to delete, then closes itself; storage is the list's job")
    func listDetailRequestsDelete() async {
        let (store, issue, issues) = makeStore(reportsToOpener: true)
        store.exhaustivity = .off

        await store.send(.detail(.deleteButtonTapped))
        await store.send(.detail(.alert(.presented(.confirmDelete))))
        await store.receive(\.detail.delegate.deleteRequested)
        await store.finish()

        #expect(navigator.sent == [.output(NavigationOutput(IssuesDetail.Output.deleteRequested(issue.id)))])
        #expect(navigator.completed == [.dismissed])
        #expect(issues.wrappedValue[id: issue.id] != nil)
    }

    @Test("A detail opened by another module edits the stored issue and reports nothing")
    func standaloneDetailSavesItself() async {
        let (store, issue, issues) = makeStore(reportsToOpener: false)

        await store.send(.detail(.titleChanged("Renamed"))) {
            $0.detail.$issue.withLock { $0.title = "Renamed" }
        }
        await store.finish()

        #expect(navigator.sent.isEmpty)
        #expect(issues.wrappedValue[id: issue.id]?.title == "Renamed")
    }

    @Test("A detail opened by another module deletes the issue itself, then closes")
    func standaloneDetailDeletesItself() async {
        let (store, issue, issues) = makeStore(reportsToOpener: false)
        store.exhaustivity = .off

        await store.send(.detail(.deleteButtonTapped))
        await store.send(.detail(.alert(.presented(.confirmDelete))))
        await store.receive(\.detail.delegate.deleteRequested)
        await store.finish()

        #expect(navigator.sent.isEmpty)
        #expect(navigator.completed == [.dismissed])
        #expect(issues.wrappedValue[id: issue.id] == nil)
    }

    @Test("The resolver builds the detail from either request, and a not-found screen for unknown ids")
    func resolverBuildsFromRequest() throws {
        try withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let issue = issues[0]
            let list = try Issues.viewController(for: Issues.route(for: Issues.detailRequest(for: issue)))
            let open = try Issues.viewController(for: Issues.route(for: NavigationRequest(intent: .open(Issues.ref(for: issue)))))
            #expect(list is UIHostingController<IssuesDetailView>)
            #expect(open is UIHostingController<IssuesDetailView>)
            #expect(!(Issues.viewController(for: .listDetails(id: UUID().uuidString)) is UIHostingController<IssuesDetailView>))
        }
    }
}
