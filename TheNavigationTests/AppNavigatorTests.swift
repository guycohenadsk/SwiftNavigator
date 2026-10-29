import ComposableArchitecture
import Foundation
import IssuesDomain
import IssuesNavigationContract
import NavigationCore
import ScreenBFeature
import ScreenBNavigationContract
import ScreenCNavigationContract
import ScreenDNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import TheNavigation

@MainActor
private func makeNavigator() -> AppNavigator {
    AppNavigator(tabRoots: [
        issuesList,
        screenB,
    ])
}

/// A navigator whose modules send every `.screenCContext` and `.open` link to their root, as Issues does.
@MainActor
private func makeNavigatorWithRootLinks() -> AppNavigator {
    let navigator = makeNavigator()
    navigator.deepLinksToRoot = { request in
        guard let route = request.route(as: IssuesNavigationContract.Route.self) else { return false }
        switch route {
        case .open, .screenCContext: return true
        default: return false
        }
    }
    return navigator
}

private let issuesList = NavigationRequest(IssuesNavigationContract.Route.list)
private let screenB = NavigationRequest(ScreenBNavigationContract.Route.home)
private let screenC = NavigationRequest(ScreenCNavigationContract.Route.home)
private let screenD = NavigationRequest(ScreenDNavigationContract.Route.home)
private let openIssue = NavigationRequest(IssuesNavigationContract.Route.open(id: "42"))
private let screenCContext = NavigationRequest(IssuesNavigationContract.Route.screenCContext)
private let issue = EntityRef(id: "42", title: "#42", open: openIssue)

/// Records the results a handler receives.
@MainActor
private final class ResultLog {
    var results: [NavigationResult] = []
    var handler: NavigationResultHandler { { [self] in results.append($0) } }
}

@MainActor
@Suite("AppNavigator")
struct AppNavigatorTests {
    @Test("Push lands on the selected tab's stack")
    func pushOnTab() {
        let navigator = makeNavigator()
        navigator.tabIndex = 1
        navigator.push(screenC)
        #expect(navigator.tabs[1].path.map(\.request) == [screenC])
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("Present opens a modal, and pushes then land inside it")
    func presentThenPush() {
        let navigator = makeNavigator()
        navigator.present(screenC)
        navigator.push(screenD)
        #expect(navigator.modals.count == 1)
        #expect(navigator.modals[0].stack.path.map(\.request) == [screenD])
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("Pop and swipe-back both report .dismissed")
    func popAndSwipeBack() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.push(screenC, onResult: log.handler)
        navigator.push(screenD, onResult: log.handler)

        navigator.pop()
        navigator.tabs[0].path = []   // what swipe-back does through the binding

        #expect(log.results == [.dismissed, .dismissed])
    }

    @Test("Completing a pushed screen hands the result back and pops it")
    func completePushed() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.push(screenC, onResult: log.handler)

        navigator.complete(with: .selectedEntity(issue))

        #expect(log.results == [.selectedEntity(issue)])
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("Completing a modal's root hands the result back and dismisses it — once")
    func completeModalRoot() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.present(NavigationRequest(IssuesNavigationContract.Route.pick), onResult: log.handler)

        navigator.complete(with: .selectedEntity(issue))

        #expect(log.results == [.selectedEntity(issue)])
        #expect(navigator.modals.isEmpty)
    }

    @Test("Dismissing a modal reports .dismissed for it and everything pushed inside it")
    func dismissModal() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.present(screenC, onResult: log.handler)
        navigator.push(screenD, onResult: log.handler)

        navigator[modalAt: 0] = nil   // what swipe-down does through the binding

        #expect(log.results == [.dismissed, .dismissed])
        #expect(navigator.modals.isEmpty)
    }

    @Test("dismiss() closes only the top modal")
    func dismissTopOnly() {
        let navigator = makeNavigator()
        navigator.present(screenC)
        navigator.present(screenD)
        navigator.dismiss()
        #expect(navigator.modals.map(\.root.request) == [screenC])
    }

    @Test("send() updates the caller and keeps the screen; leaving then reports .dismissed")
    func sendKeepsScreen() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.push(NavigationRequest(ScreenCNavigationContract.Route.compose(prompt: "Hi")), onResult: log.handler)

        navigator.send(.output(NavigationOutput("one")))
        navigator.send(.output(NavigationOutput("two")))
        #expect(navigator.tabs[0].path.count == 1)

        navigator.pop()
        #expect(log.results == [.output(NavigationOutput("one")), .output(NavigationOutput("two")), .dismissed])
    }

    @Test("send() from a modal's root reaches whoever presented it")
    func sendFromModalRoot() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.present(NavigationRequest(ScreenCNavigationContract.Route.compose(prompt: "Hi")), onResult: log.handler)

        navigator.send(.output(NavigationOutput("hi")))

        #expect(log.results == [.output(NavigationOutput("hi"))])
        #expect(navigator.modals.count == 1)
    }

    @Test("Completing with an output delivers it, then leaves with .dismissed")
    func completeWithMessage() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.push(screenC, onResult: log.handler)

        navigator.complete(with: .output(NavigationOutput("bye")))

        #expect(log.results == [.output(NavigationOutput("bye")), .dismissed])
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("pushForResults streams every update and ends when the screen leaves")
    func pushForResultsStream() async {
        let navigator = makeNavigator()
        let results = navigator.pushForResults(NavigationRequest(ScreenCNavigationContract.Route.compose(prompt: "Hi")))
        navigator.send(.output(NavigationOutput("one")))
        navigator.pop()

        var received: [NavigationResult] = []
        for await result in results { received.append(result) }
        #expect(received == [.output(NavigationOutput("one")), .dismissed])
    }

    @Test("pushForOutputs yields only outputs of the asked type and ends when the screen leaves")
    func pushForOutputsStream() async {
        let navigator = makeNavigator()
        let outputs = navigator.pushForOutputs(NavigationRequest(ScreenCNavigationContract.Route.compose(prompt: "Hi")), as: String.self)
        navigator.send(.output(NavigationOutput("one")))
        navigator.send(.output(NavigationOutput(2)))
        navigator.send(.output(NavigationOutput("three")))
        navigator.pop()

        var received: [String] = []
        for await output in outputs { received.append(output) }
        #expect(received == ["one", "three"])
    }

    @Test("pushForResult returns the picked entity once the pushed picker completes")
    func pushForResult() async {
        let navigator = makeNavigator()
        async let result = navigator.pushForResult(NavigationRequest(IssuesNavigationContract.Route.pick))
        await Task.yield()
        #expect(navigator.tabs[0].path.count == 1)
        navigator.complete(with: .selectedEntity(issue))
        #expect(await result == .selectedEntity(issue))
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("presentForResult returns the picked entity")
    func presentForResult() async {
        let navigator = makeNavigator()
        async let result = navigator.presentForResult(NavigationRequest(IssuesNavigationContract.Route.pick))
        await Task.yield()
        navigator.complete(with: .selectedEntity(issue))
        #expect(await result == .selectedEntity(issue))
    }

    // MARK: Deep links

    @Test("A deep link dismisses modals, switches to the module's tab, resets it, and pushes")
    func deepLinkToOwningTab() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.tabs[0].push(NavigationEntry(request: screenC), onResult: log.handler)
        navigator.tabIndex = 1
        navigator.present(screenD, onResult: log.handler)

        navigator.open(deepLink: openIssue)

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.map(\.request) == [openIssue])
        #expect(log.results == [.dismissed, .dismissed])
    }

    @Test("A root-bound deep link lands on the module's tab and hands it to that tab's root")
    func deepLinkPerform() async {
        let navigator = makeNavigatorWithRootLinks()
        let rootActions = navigator.incomingRequests(for: .issues)   // the Issues tab root subscribes
        navigator.tabIndex = 1
        navigator.present(screenD)

        navigator.open(deepLink: screenCContext)

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(await rootActions.first { _ in true } == screenCContext)
    }

    @Test("A root-bound deep link skips screens pushed above the root and same-module screens on other stacks")
    func deepLinkPerformOnlyRoot() async {
        let navigator = makeNavigatorWithRootLinks()
        let rootActions = navigator.incomingRequests(for: .issues)
        navigator.push(issuesList)
        let pushedActions = navigator.incomingRequests(for: .issues)
        navigator.tabIndex = 1
        let otherTabActions = navigator.incomingRequests(for: .issues)

        navigator.open(deepLink: NavigationRequest(IssuesNavigationContract.Route.open(id: "go")))
        navigator.open(deepLink: NavigationRequest(IssuesNavigationContract.Route.open(id: "again")))

        var received: [NavigationRequest] = []
        for await request in rootActions.prefix(2) { received.append(request) }
        #expect(received == [NavigationRequest(IssuesNavigationContract.Route.open(id: "go")), NavigationRequest(IssuesNavigationContract.Route.open(id: "again"))])
        _ = (pushedActions, otherTabActions)   // kept alive, never fed
    }

    @Test("A root-bound deep link that lands before the root subscribes is held until it does")
    func deepLinkPerformBeforeSubscribe() async {
        let navigator = makeNavigatorWithRootLinks()
        navigator.open(deepLink: screenCContext)

        let rootActions = navigator.incomingRequests(for: .issues)

        #expect(await rootActions.first { _ in true } == screenCContext)
    }

    @Test("A deep link its module sends to the root lands on the module's tab and goes to that root, not the stack")
    func deepLinkToRoot() async {
        let navigator = makeNavigatorWithRootLinks()
        let rootRequests = navigator.incomingRequests(for: .issues)
        navigator.tabIndex = 1
        navigator.present(screenD)

        navigator.open(deepLink: openIssue)

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(await rootRequests.first { _ in true } == openIssue)
    }

    @Test("A deep link for the root of a module without a tab goes to the current tab's root screen, not onto its stack")
    func deepLinkToRootWithoutTab() {
        let navigator = makeNavigator()
        navigator.deepLinksToRoot = { _ in true }
        navigator.open(deepLink: screenD)
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(navigator.pendingRequestCount == 1)   // held until a screen subscribes
    }

    @Test("A deep link to a tab's own root just selects that tab")
    func deepLinkToTabRoot() {
        let navigator = makeNavigator()
        navigator.open(deepLink: screenB)
        #expect(navigator.tabIndex == 1)
        #expect(navigator.tabs[1].path.isEmpty)
    }

    @Test("A deep link to a module without a tab pushes on the current tab")
    func deepLinkWithoutTab() {
        let navigator = makeNavigator()
        navigator.open(deepLink: screenD)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.map(\.request) == [screenD])
    }
}

/// A screen closing itself while an alert is still going away: `UINavigationController` ignores a
/// pop under a presentation, so the entry leaves once nothing covers its stack.
@MainActor
@Suite("AppNavigator removals under a presentation", .serialized)
struct AppNavigatorCoveredRemovalTests {
    /// A tab stack shown in a window, with `cover` presented over it from the window's root.
    private func makeCoveredStack() async throws -> (AppNavigator, UIViewController, UIWindow) {
        let navigator = makeNavigator()
        let controller = UINavigationController(rootViewController: UIViewController())
        navigator.tabs[0].controller = controller
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let cover = UIViewController()
        controller.present(cover, animated: false)
        try #require(controller.presentedViewController === cover)
        return (navigator, cover, window)
    }

    @Test("complete(with:) reports the result at once, and removes the entry once the cover is gone")
    func completeWaitsForCover() async throws {
        let (navigator, _, window) = try await makeCoveredStack()
        let log = ResultLog()
        navigator.push(screenC, onResult: log.handler)

        navigator.complete(with: .dismissed)

        #expect(log.results == [.dismissed])
        // The cover was up and not leaving, so it is closed; the entry goes after it.
        for _ in 0..<60 where !navigator.tabs[0].path.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(window.rootViewController?.presentedViewController == nil)
        #expect(log.results == [.dismissed])
    }

    @Test("Without a window (or with nothing covering) complete and pop remove at once")
    func uncoveredRemovesAtOnce() {
        let navigator = makeNavigator()
        let log = ResultLog()
        navigator.push(screenC, onResult: log.handler)
        navigator.push(screenD)

        navigator.pop()
        #expect(navigator.tabs[0].path.map(\.request) == [screenC])
        navigator.complete(with: .selectedEntity(issue))
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(log.results == [.selectedEntity(issue)])
    }
}

/// `NavigationContext.onLeave`, as AppComposition ties it to an entry: it runs once, however the
/// entry leaves.
@MainActor
@Suite("AppNavigator entry leave actions")
struct AppNavigatorLeaveTests {
    private let request = NavigationRequest(IssuesNavigationContract.Route.listDetails(id: "x"))

    @Test("onLeave runs once for a pop, a complete and a deep-link reset; never for entries still there")
    func onLeaveFiresOnce() {
        let navigator = makeNavigator()
        let stack = navigator.tabs[0]
        var leaves = 0
        let leaving: [() -> Void] = [
            { navigator.pop() },
            { navigator.complete(with: .dismissed) },
            { navigator.open(deepLink: issuesList) },
        ]

        for leave in leaving {
            navigator.push(request)
            stack.onLeave(stack.path.last!.id) { leaves += 1 }
            navigator.push(screenC)
            navigator.pop()
            #expect(stack.path.map(\.request) == [request])
            leave()
        }
        #expect(stack.path.isEmpty)
        #expect(leaves == 3)
    }
}

@MainActor
@Suite("AppComposition")
struct AppCompositionTests {
    @Test("Issues sends linked issues to its tab's list; other links are resolved")
    func registryDeepLinksToRoot() throws {
        let registry = try AppComposition.makeRegistry()
        #expect(registry.deepLinksToRoot(openIssue))
        #expect(!registry.deepLinksToRoot(issuesList))
        #expect(registry.deepLinksToRoot(screenCContext))
        #expect(!registry.deepLinksToRoot(screenB))
    }

    @Test("The app's registry turns deep-link URLs into each module's routes")
    func registryDeepLinks() throws {
        let registry = try AppComposition.makeRegistry()
        #expect(try registry.request(for: #require(URL(string: "demoapp://issues"))) == issuesList)
        #expect(try registry.request(for: #require(URL(string: "demoapp://issues/42"))) == openIssue)
        #expect(try registry.request(for: #require(URL(string: "demoapp://issues?action=screenCContext"))) == screenCContext)
        #expect(try registry.request(for: #require(URL(string: "demoapp://screenB"))) == screenB)
        #expect(try registry.request(for: #require(URL(string: "demoapp://screenD"))) == screenD)
    }

    @Test("Every NavigationTarget is registered exactly once")
    func everyTargetRegistered() throws {
        let registry = try AppComposition.makeRegistry()
        #expect(registry.registeredTargets == Set(NavigationTarget.allCases))
    }

    /// The Issues list's own detail needs the list as its parent; IssuesDomainTests cover it.
    @Test("Modules' screens resolve from their requests")
    func innerScreensResolve() throws {
        let registry = try AppComposition.makeRegistry()
        let stored = Issue(title: "Stored")
        let (detail, b2) = withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = [stored] }
            let navigator = makeNavigator()
            let resolve = { (request: NavigationRequest) in try? registry.resolve(request, navigator: navigator) }
            return (
                resolve(NavigationRequest(IssuesNavigationContract.Route.open(id: stored.id.uuidString))),
                resolve(NavigationRequest(ScreenBNavigationContract.Route.b2))
            )
        }
        #expect(detail is UIHostingController<IssuesDetailView>)
        #expect(b2 is UIHostingController<ScreenB2View>)
    }

    @Test("Every tab root resolves")
    func tabRootsResolve() throws {
        let registry = try AppComposition.makeRegistry()
        try withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            let navigator = makeNavigator()
            for tab in AppComposition.tabs {
                _ = try registry.resolve(tab.root, navigator: navigator)
            }
        }
    }
}
