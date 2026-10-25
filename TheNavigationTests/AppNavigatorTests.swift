import ComposableArchitecture
import Foundation
import NavigationCore
import Testing
import UIKit

@testable import TheNavigation

@MainActor
private func makeNavigator() -> AppNavigator {
    AppNavigator(tabRoots: [
        NavigationRequest(intent: .browse(.issues)),
        NavigationRequest(intent: .browse(.screenB)),
    ])
}

private let screenC = NavigationRequest(intent: .browse(.screenC))
private let screenD = NavigationRequest(intent: .browse(.screenD))
private let issue = EntityRef(target: .issues, id: "42", title: "#42")

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
        navigator.present(NavigationRequest(intent: .selectSingle(.issues)), onResult: log.handler)

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
        navigator.push(NavigationRequest(intent: .compose(.screenC, prompt: "Hi")), onResult: log.handler)

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
        navigator.present(NavigationRequest(intent: .compose(.screenC, prompt: "Hi")), onResult: log.handler)

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
        let results = navigator.pushForResults(NavigationRequest(intent: .compose(.screenC, prompt: "Hi")))
        navigator.send(.output(NavigationOutput("one")))
        navigator.pop()

        var received: [NavigationResult] = []
        for await result in results { received.append(result) }
        #expect(received == [.output(NavigationOutput("one")), .dismissed])
    }

    @Test("pushForOutputs yields only outputs of the asked type and ends when the screen leaves")
    func pushForOutputsStream() async {
        let navigator = makeNavigator()
        let outputs = navigator.pushForOutputs(NavigationRequest(intent: .compose(.screenC, prompt: "Hi")), as: String.self)
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
        async let result = navigator.pushForResult(NavigationRequest(intent: .selectSingle(.issues)))
        await Task.yield()
        #expect(navigator.tabs[0].path.count == 1)
        navigator.complete(with: .selectedEntity(issue))
        #expect(await result == .selectedEntity(issue))
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("presentForResult returns the picked entity")
    func presentForResult() async {
        let navigator = makeNavigator()
        async let result = navigator.presentForResult(NavigationRequest(intent: .selectSingle(.issues)))
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

        navigator.open(deepLink: NavigationRequest(intent: .open(issue)))

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.map(\.request) == [NavigationRequest(intent: .open(issue))])
        #expect(log.results == [.dismissed, .dismissed])
    }

    @Test("A .perform deep link lands on the module's tab and hands the action to that tab's root")
    func deepLinkPerform() async {
        let navigator = makeNavigator()
        let rootActions = navigator.incomingRequests(for: .issues)   // the Issues tab root subscribes
        navigator.tabIndex = 1
        navigator.present(screenD)

        navigator.open(deepLink: NavigationRequest(intent: .perform(.issues, action: "screenCContext")))

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(await rootActions.first { _ in true } == NavigationRequest(intent: .perform(.issues, action: "screenCContext")))
    }

    @Test("A .perform deep link skips screens pushed above the root and same-module screens on other stacks")
    func deepLinkPerformOnlyRoot() async {
        let navigator = makeNavigator()
        let rootActions = navigator.incomingRequests(for: .issues)
        navigator.push(NavigationRequest(intent: .browse(.issues)))
        let pushedActions = navigator.incomingRequests(for: .issues)
        navigator.tabIndex = 1
        let otherTabActions = navigator.incomingRequests(for: .issues)

        navigator.open(deepLink: NavigationRequest(intent: .perform(.issues, action: "go")))
        navigator.open(deepLink: NavigationRequest(intent: .perform(.issues, action: "again")))

        var received: [NavigationRequest] = []
        for await request in rootActions.prefix(2) { received.append(request) }
        #expect(received == [NavigationRequest(intent: .perform(.issues, action: "go")), NavigationRequest(intent: .perform(.issues, action: "again"))])
        _ = (pushedActions, otherTabActions)   // kept alive, never fed
    }

    @Test("A .perform deep link that lands before the root subscribes is held until it does")
    func deepLinkPerformBeforeSubscribe() async {
        let navigator = makeNavigator()
        navigator.open(deepLink: NavigationRequest(intent: .perform(.issues, action: "screenCContext")))

        let rootActions = navigator.incomingRequests(for: .issues)

        #expect(await rootActions.first { _ in true } == NavigationRequest(intent: .perform(.issues, action: "screenCContext")))
    }

    @Test("A deep link its module sends to the root lands on the module's tab and goes to that root, not the stack")
    func deepLinkToRoot() async {
        let navigator = makeNavigator()
        navigator.deepLinksToRoot = { if case .open = $0.intent { true } else { false } }
        let rootRequests = navigator.incomingRequests(for: .issues)
        navigator.tabIndex = 1
        navigator.present(screenD)

        navigator.open(deepLink: NavigationRequest(intent: .open(issue)))

        #expect(navigator.modals.isEmpty)
        #expect(navigator.tabIndex == 0)
        #expect(navigator.tabs[0].path.isEmpty)
        #expect(await rootRequests.first { _ in true } == NavigationRequest(intent: .open(issue)))
    }

    @Test("A deep link sent to the root of a module without a tab is pushed on the current tab instead")
    func deepLinkToRootWithoutTab() {
        let navigator = makeNavigator()
        navigator.deepLinksToRoot = { _ in true }
        navigator.open(deepLink: screenD)
        #expect(navigator.tabs[0].path.map(\.request) == [screenD])
    }

    @Test("A deep link to a tab's own root just selects that tab")
    func deepLinkToTabRoot() {
        let navigator = makeNavigator()
        navigator.open(deepLink: NavigationRequest(intent: .browse(.screenB)))
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

/// Entries a parent pushes with `push(local:…)`: its child's state stays with the parent.
@MainActor
@Suite("AppNavigator local entries")
struct AppNavigatorLocalEntryTests {
    private let detail = NavigationRequest(intent: .open(EntityRef(target: .issues, id: "42", title: "#42")))

    /// A navigator whose stacks are bound to UIKit controllers, as AppComposition does.
    private func makeBoundNavigator() -> (AppNavigator, [UINavigationController]) {
        let navigator = makeNavigator()
        let controllers = navigator.tabs.map { stack in
            let controller = UINavigationController(rootViewController: UIViewController())
            stack.controller = controller
            return controller
        }
        return (navigator, controllers)
    }

    @Test("A local push lands on top of the stack showing the parent, and builds its own screen")
    func pushesOnParentsStack() throws {
        let (navigator, controllers) = makeBoundNavigator()
        let parent = try #require(controllers[0].viewControllers.first)
        let screen = UIViewController()

        let id = navigator.push(local: detail, from: parent, screen: { screen }, onDismiss: {})

        #expect(navigator.tabs[0].path.map(\.id) == [id])
        #expect(navigator.tabs[0].path.map(\.request) == [detail])
        #expect(navigator.tabs[0].localScreen(for: id) === screen)
    }

    @Test("A local push goes to the parent's stack even when a modal is on top")
    func pushesUnderModal() throws {
        let (navigator, controllers) = makeBoundNavigator()
        navigator.present(screenD)

        let id = navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: {})

        #expect(navigator.tabs[0].path.map(\.id) == [id])
        #expect(navigator.modals.first?.stack.path.isEmpty == true)
    }

    @Test("A parent not on any bound stack falls back to the current stack")
    func fallsBackToCurrent() {
        let navigator = makeNavigator()
        navigator.tabIndex = 1
        let id = navigator.push(local: detail, from: UIViewController(), screen: { UIViewController() }, onDismiss: {})
        #expect(navigator.tabs[1].path.map(\.id) == [id])
    }

    @Test("Popping a local entry calls onDismiss once and forgets its screen")
    func popDismisses() throws {
        let (navigator, controllers) = makeBoundNavigator()
        var dismissals = 0
        let id = navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: { dismissals += 1 })

        navigator.pop()
        navigator.pop()

        #expect(dismissals == 1)
        #expect(navigator.tabs[0].localScreen(for: id) == nil)
    }

    @Test("A deep-link reset dismisses local entries too")
    func resetDismisses() throws {
        let (navigator, controllers) = makeBoundNavigator()
        var dismissals = 0
        navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: { dismissals += 1 })

        navigator.open(deepLink: NavigationRequest(intent: .browse(.issues)))

        #expect(dismissals == 1)
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("remove() takes the entry and everything above it; only the entries above report .dismissed")
    func removeTakesAbove() throws {
        let (navigator, controllers) = makeBoundNavigator()
        var dismissals = 0
        let log = ResultLog()
        let id = navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: { dismissals += 1 })
        navigator.push(screenC, onResult: log.handler)

        navigator.remove(id)

        #expect(navigator.tabs[0].path.isEmpty)
        #expect(dismissals == 0)
        #expect(log.results == [.dismissed])
        #expect(navigator.tabs[0].localScreen(for: id) == nil)
    }

    @Test("A local entry the child completes itself (a final result) still calls onDismiss")
    func completeDismisses() throws {
        let (navigator, controllers) = makeBoundNavigator()
        var dismissals = 0
        navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: { dismissals += 1 })

        navigator.complete(with: .selectedEntity(EntityRef(target: .issues, id: "1", title: "")))

        #expect(dismissals == 1)
        #expect(navigator.tabs[0].path.isEmpty)
    }

    @Test("present(local:) opens a modal whose root is the parent's screen; leaving it calls onDismiss")
    func presentLocal() {
        let navigator = makeNavigator()
        var dismissals = 0
        let screen = UIViewController()

        let id = navigator.present(local: detail, screen: { screen }, onDismiss: { dismissals += 1 })

        #expect(navigator.modals.map(\.root.id) == [id])
        #expect(navigator.modals.first?.root.request == detail)
        #expect(navigator.modals.first?.localScreen?() === screen)

        navigator.dismiss()
        #expect(dismissals == 1)
        #expect(navigator.modals.isEmpty)
    }

    @Test("A locally presented modal also reports a swipe-down and a deep-link reset")
    func presentLocalReset() {
        let navigator = makeNavigator()
        var dismissals = 0
        navigator.present(local: detail, screen: { UIViewController() }, onDismiss: { dismissals += 1 })
        navigator[modalAt: 0] = nil   // swipe-down
        #expect(dismissals == 1)

        navigator.present(local: detail, screen: { UIViewController() }, onDismiss: { dismissals += 1 })
        navigator.open(deepLink: NavigationRequest(intent: .browse(.screenB)))
        #expect(dismissals == 2)
    }

    @Test("remove() of a locally presented modal takes it and every modal above, reporting only those above")
    func removePresentedLocal() {
        let navigator = makeNavigator()
        var dismissals = 0
        let log = ResultLog()
        let id = navigator.present(local: detail, screen: { UIViewController() }, onDismiss: { dismissals += 1 })
        navigator.present(screenC, onResult: log.handler)

        navigator.remove(id)

        #expect(navigator.modals.isEmpty)
        #expect(dismissals == 0)
        #expect(log.results == [.dismissed])
    }

    @Test("remove() finds the entry on a background tab, and ignores ids that are gone")
    func removeAnywhere() throws {
        let (navigator, controllers) = makeBoundNavigator()
        let id = navigator.push(local: detail, from: try #require(controllers[0].viewControllers.first), screen: { UIViewController() }, onDismiss: {})
        navigator.tabIndex = 1
        navigator.push(screenC)

        navigator.remove(id)
        navigator.remove(id)
        navigator.remove(NavigationEntry.ID())

        #expect(navigator.tabs[0].path.isEmpty)
        #expect(navigator.tabs[1].path.map(\.request) == [screenC])
    }
}

@MainActor
@Suite("AppComposition")
struct AppCompositionTests {
    @Test("Issues sends linked issues to its tab's list; other links are resolved")
    func registryDeepLinksToRoot() throws {
        let registry = try AppComposition.makeRegistry()
        #expect(registry.deepLinksToRoot(NavigationRequest(intent: .open(issue))))
        #expect(!registry.deepLinksToRoot(NavigationRequest(intent: .browse(.issues))))
        #expect(!registry.deepLinksToRoot(NavigationRequest(intent: .browse(.screenB))))
    }

    @Test("Every NavigationTarget is registered exactly once")
    func everyTargetRegistered() throws {
        let registry = try AppComposition.makeRegistry()
        #expect(registry.registeredTargets == Set(NavigationTarget.allCases))
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
