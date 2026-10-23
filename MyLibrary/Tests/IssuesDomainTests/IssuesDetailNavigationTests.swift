import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import SwiftUI
import Testing
import UIKit

@testable import IssuesDomain

/// Records the detail pushes the list makes through the navigator, and the entries it removes.
@MainActor
private final class DetailNavigatorSpy: Navigator {
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

/// The list's detail travels through the navigator, while its state stays in the list.
@MainActor
@Suite("Issues list → detail through the navigator", .serialized)
struct IssuesDetailNavigationTests {
    private let spy = DetailNavigatorSpy()
    let store: StoreOf<IssuesList>
    let controller: IssuesListHostingController

    init() {
        let spy = spy
        (store, controller) = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = spy
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            let store = Store(initialState: IssuesList.State()) { IssuesList() }
            return (store, IssuesListHostingController(store: store))
        }
        controller.loadViewIfNeeded()
    }

    private var firstIssue: IssuesDomain.Issue { store.issues[0] }

    @Test("Tapping a row sets the list's detail state and pushes it as an .open entry")
    func tapPushes() async throws {
        store.send(.issueTapped(firstIssue.id))
        await settle()

        #expect(store.detail?.issue.id == firstIssue.id)
        let push = try #require(spy.pushes.first)
        #expect(spy.pushes.count == 1)
        #expect(push.request == NavigationRequest(intent: .open(Issues.ref(for: firstIssue))))
        #expect(push.screen() is UIHostingController<IssuesDetailView>)
    }

    @Test("Leaving the detail (back, swipe, reset) clears the list's detail state")
    func dismissClearsState() async throws {
        store.send(.issueTapped(firstIssue.id))
        await settle()

        try #require(spy.pushes.first).onDismiss()
        await settle()

        #expect(store.detail == nil)
        #expect(spy.removed.isEmpty)
    }

    @Test("The detail asking its parent to delete: the list clears state and the entry is removed")
    func deleteRemovesEntry() async throws {
        let issue = firstIssue
        store.send(.issueTapped(issue.id))
        await settle()
        let push = try #require(spy.pushes.first)

        store.send(.detail(.presented(.delegate(.deleteRequested))))
        await settle()

        #expect(store.detail == nil)
        #expect(store.issues[id: issue.id] == nil)
        #expect(spy.removed == [push.id])
    }

    @Test("Editing the detail's issue keeps the same entry")
    func editKeepsEntry() async {
        store.send(.issueTapped(firstIssue.id))
        await settle()

        store.send(.detail(.presented(.titleChanged("Renamed"))))
        await settle()

        #expect(store.detail?.issue.title == "Renamed")
        #expect(spy.pushes.count == 1)
        #expect(spy.removed.isEmpty)
    }

    @Test("Opening another issue after leaving pushes a fresh entry")
    func reopen() async throws {
        store.send(.issueTapped(firstIssue.id))
        await settle()
        try #require(spy.pushes.first).onDismiss()
        await settle()

        store.send(.issueTapped(store.issues[1].id))
        await settle()

        #expect(spy.pushes.count == 2)
        #expect(store.detail?.issue.id == store.issues[1].id)
    }
}
