import ComposableArchitecture
import Foundation
import NavigationCore
import ScreenCKit
import SwiftUI
import Testing
import UIKit

import IssuesNavigationContract

@testable import IssuesDomain
@testable import TheNavigation

/// Every screen the navigator shows goes away once it leaves, with what the navigator kept for it.
///
/// Drives the running test host — its window, its `AppNavigator`, the real composition — because
/// the navigator dependency is bound once per process. Each test starts and ends on the Issues tab
/// with nothing pushed or presented, and creates the issues it deletes.
@MainActor
@Suite("Memory: screens are released when they leave", .serialized)
struct MemoryTests {
    private let navigator: AppNavigator
    private let tabBar: UITabBarController

    init() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let delegate = try #require(scene.delegate as? SceneDelegate)
        navigator = delegate.navigator
        tabBar = try #require(delegate.window?.rootViewController as? UITabBarController)
        await Self.prepareLiveGenerators()
        try await reset()
    }

    // MARK: - Issues list → its own detail

    @Test("A list's detail is released after back, with the list's state and the stack's hooks cleared")
    func listDetailReleasedAfterBack() async throws {
        let list = try issuesList()
        await inApp { list.store.send(.issueTapped(list.store.issues[0].id)) }
        weak var detail = try await waitForTop(of: issuesStack, UIHostingController<IssuesDetailView>.self)
        #expect(navigator.tabs[0].leaveActionCount == 1)

        await inApp { navigator.pop() }

        try await waitUntil { detail == nil }
        #expect(list.store.detail == nil)
        #expect(navigator.tabs[0].leaveActionCount == 0)
        #expect(navigator.tabs[0].handlerCount == 0)
    }

    @Test("A list's detail is released after its delete, which the list pops")
    func listDetailReleasedAfterDelete() async throws {
        let list = try issuesList()
        await inApp { list.store.send(.addIssueTapped) }
        weak var detail = try await waitForTop(of: issuesStack, UIHostingController<IssuesDetailView>.self)
        let id = try #require(list.store.detail?.issue.id)

        await inApp { list.store.send(.detail(.presented(.delegate(.deleteRequested)))) }

        try await waitUntil { detail == nil && self.navigator.tabs[0].path.isEmpty }
        #expect(list.store.issues[id: id] == nil)
        #expect(navigator.tabs[0].leaveActionCount == 0)
    }

    @Test("A deep-linked issue's detail is released when another deep link resets the tab")
    func deepLinkedDetailReleasedOnReset() async throws {
        let list = try issuesList()
        let ref = Issues.ref(for: list.store.issues[1])
        await inApp { navigator.open(deepLink: NavigationRequest(IssuesNavigationContract.Route.open(id: ref.id))) }
        weak var detail = try await waitForTop(of: issuesStack, UIHostingController<IssuesDetailView>.self)

        await inApp { navigator.open(deepLink: NavigationRequest(IssuesNavigationContract.Route.list)) }

        try await waitUntil { detail == nil }
        #expect(list.store.detail == nil)
        #expect(navigator.tabs[0].leaveActionCount == 0)
    }

    // MARK: - Issues list → Screen C (typed outputs)

    @Test("Screen C pushed with context is released after back, with its result handler")
    func screenCContextReleased() async throws {
        let list = try issuesList()
        await inApp { list.store.send(.pushScreenCWithContextTapped) }
        weak var screenC = try await waitForTop(of: issuesStack, ScreenCViewController.self)
        #expect(navigator.tabs[0].handlerCount == 1)

        await inApp { navigator.pop() }

        try await waitUntil { screenC == nil }
        #expect(navigator.tabs[0].handlerCount == 0)
    }

    // MARK: - Standalone details

    @Test("A standalone detail (.open, random) is released after back", arguments: [false, true])
    func standaloneDetailReleased(random: Bool) async throws {
        let list = try issuesList()
        let request = random
            ? NavigationRequest(IssuesNavigationContract.Route.random)
            : NavigationRequest(IssuesNavigationContract.Route.open(id: Issues.ref(for: list.store.issues[2]).id))
        await inApp { navigator.push(request) }
        weak var detail = try await waitForTop(of: issuesStack, UIHostingController<IssuesDetailView>.self)

        await inApp { navigator.pop() }

        try await waitUntil { detail == nil }
        #expect(list.store.detail == nil)   // not the list's child
    }

    // MARK: - Modals

    @Test("A presented Issues list, its detail, stack and deep-link subscription are released on dismiss")
    func presentedListReleased() async throws {
        let subscribers = navigator.rootSubscriberCount
        weak var weakModal: UINavigationController?
        weak var weakList: IssuesListHostingController?
        weak var weakStore: StoreOf<IssuesList>?
        weak var weakDetail: UIViewController?
        weak var weakStack: StackNavigator?
        do {
            await inApp { navigator.present(NavigationRequest(IssuesNavigationContract.Route.list)) }
            let modal = try await waitForModal()
            let modalList = try await waitForTop(of: modal, IssuesListHostingController.self)
            try await waitUntil { self.navigator.rootSubscriberCount == subscribers + 1 }

            await inApp { modalList.store.send(.issueTapped(modalList.store.issues[0].id)) }
            let modalDetail = try await waitForTop(of: modal, UIHostingController<IssuesDetailView>.self)
            weakModal = modal
            weakList = modalList
            weakStore = modalList.store
            weakDetail = modalDetail
            weakStack = navigator.modals.first?.stack
        }

        await inApp { navigator.dismiss() }

        try? await waitUntil {
            weakModal == nil && weakList == nil && weakStore == nil && weakDetail == nil && weakStack == nil
        }
        #expect(weakModal == nil)
        #expect(weakList == nil)
        #expect(weakStore == nil)
        #expect(weakDetail == nil)
        #expect(weakStack == nil)
        try await waitUntil { self.navigator.rootSubscriberCount == subscribers }
        #expect(navigator.pendingRequestCount == 0)
    }

    @Test("A presented picker is released once it picks, with its result handler")
    func presentedPickerReleased() async throws {
        let results = ResultLog()
        weak var weakModal: UINavigationController?
        weak var weakPicker: IssuesListHostingController?
        do {
            await inApp { navigator.present(NavigationRequest(IssuesNavigationContract.Route.pick)) { results.values.append($0) } }
            let modal = try await waitForModal()
            let picker = try await waitForTop(of: modal, IssuesListHostingController.self)
            weakModal = modal
            weakPicker = picker

            await inApp { picker.store.send(.issueTapped(picker.store.issues[0].id)) }
        }

        try? await waitUntil { weakModal == nil && weakPicker == nil }
        #expect(weakModal == nil)
        #expect(weakPicker == nil)
        #expect(results.values.count == 1)
        #expect(navigator.modals.isEmpty)
    }

    // MARK: - Helpers

    private var issuesStack: UINavigationController {
        get throws { try #require(tabBar.viewControllers?.first as? UINavigationController) }
    }

    private func issuesList() throws -> IssuesListHostingController {
        try #require(issuesStack.viewControllers.first as? IssuesListHostingController)
    }

    /// The test host runs in the test context, where `uuid`, `date` and the random generator have no
    /// live value. The real app gets the live ones; so does the host, once, outside any test.
    private static var preparedGenerators = false
    private static func prepareLiveGenerators() async {
        guard !preparedGenerators else { return }
        preparedGenerators = true
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                prepareDependencies {
                    $0.uuid = UUIDGenerator { UUID() }
                    $0.date = DateGenerator { Date() }
                    $0.withRandomNumberGenerator = WithRandomNumberGenerator(SystemRandomNumberGenerator())
                }
                continuation.resume()
            }
        }
    }

    /// Back to the Issues tab, nothing pushed or presented, and UIKit caught up.
    private func reset() async throws {
        await inApp { [navigator] in
            navigator.modals = []
            navigator.tabs.forEach { $0.path = [] }
            navigator.tabIndex = 0
        }
        try await waitUntil {
            self.tabBar.presentedViewController == nil
                && (try? self.issuesStack.viewControllers.count) == 1
                && self.tabBar.selectedIndex == 0
        }
    }

    /// Runs `body` on the main queue, outside this test's task. The app's dependencies (its live
    /// navigator, its storage) are bound once per process, while swift-dependencies gives code in a
    /// Swift Testing test's task fresh test values instead.
    private func inApp(_ body: @escaping @MainActor () -> Void) async {
        nonisolated(unsafe) let body = body
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { body() }
                continuation.resume()
            }
        }
    }

    /// The modal's navigation controller once it is up.
    private func waitForModal() async throws -> UINavigationController {
        try await waitUntil { self.tabBar.presentedViewController is UINavigationController }
        return try #require(tabBar.presentedViewController as? UINavigationController)
    }

    /// `stack`'s top screen once it is a `T`.
    private func waitForTop<T: UIViewController>(of stack: UINavigationController, _ type: T.Type) async throws -> T {
        try await waitUntil { stack.topViewController is T }
        return try #require(stack.topViewController as? T)
    }

    /// Lets UIKit run (animations, presentation, deallocation) until `condition` holds, up to 5s.
    private func waitUntil(_ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(condition(), "Timed out", sourceLocation: sourceLocation)
        if !condition() { throw CancellationError() }
    }
}

/// Collects the results a handler receives.
@MainActor
private final class ResultLog {
    var values: [NavigationResult] = []
}
