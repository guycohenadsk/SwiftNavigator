import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import ScreenBNavigationContract
import ScreenCNavigationContract
import ScreenDNavigationContract
import SwiftUI
import Testing
import UIKit

@testable import IssuesDomain
@testable import ScreenBFeature
@testable import ScreenCKit
@testable import ScreenDKit

@MainActor
@Suite("Feature navigation")
struct FeatureNavigationTests {
    private func link(_ target: NavigationTarget, path: [String] = [], query: [String: String] = [:]) -> DeepLink {
        DeepLink(target: target, path: path, query: query)
    }

    @Test("Issues declares its deep links: list, one issue, and the Screen C action")
    func issuesDeepLinks() {
        let issues = Issues.navigationRegistration
        #expect(issues.deepLink(link(.issues)) == NavigationRequest(IssuesNavigationContract.Route.list))
        #expect(issues.deepLink(link(.issues, path: ["abc"])) == NavigationRequest(IssuesNavigationContract.Route.open(id: "abc")))
        #expect(
            issues.deepLink(link(.issues, query: ["action": "screenCContext"]))
                == NavigationRequest(IssuesNavigationContract.Route.screenCContext)
        )
        #expect(issues.deepLink(link(.issues, query: ["action": ""])) == nil)
        #expect(issues.deepLink(link(.issues, query: ["action": "nope"])) == nil)
    }

    @Test("Issues hands issue links and its action to its root screen, but not the list")
    func issuesDeepLinksToRoot() {
        let issues = Issues.navigationRegistration
        #expect(issues.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.open(id: "abc"))))
        #expect(issues.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.screenCContext)))
        #expect(!issues.deepLinksToRoot(NavigationRequest(IssuesNavigationContract.Route.list)))
    }

    @Test("Screens B, C and D open at home from a bare link, and offer nothing else")
    func screenDeepLinks() {
        #expect(ScreenB.navigationRegistration.deepLink(link(.screenB)) == NavigationRequest(ScreenBNavigationContract.Route.home))
        #expect(ScreenC.navigationRegistration.deepLink(link(.screenC)) == NavigationRequest(ScreenCNavigationContract.Route.home))
        #expect(ScreenD.navigationRegistration.deepLink(link(.screenD)) == NavigationRequest(ScreenDNavigationContract.Route.home))
        #expect(ScreenB.navigationRegistration.deepLink(link(.screenB, path: ["b2"])) == nil)
        #expect(ScreenC.navigationRegistration.deepLink(link(.screenC, query: ["action": "x"])) == nil)
    }

    @Test("Every module rejects requests addressed to another module")
    func wrongTarget() {
        let context = NavigationContext(navigator: NavigatorStub())
        let other = NavigationRequest(ScreenDNavigationContract.Route.home)
        for registration in [Issues.navigationRegistration, ScreenB.navigationRegistration, ScreenC.navigationRegistration] {
            #expect(throws: NavigationError.wrongTarget) { try registration.resolver(other, context) }
        }
        let issues = NavigationRequest(IssuesNavigationContract.Route.list)
        #expect(throws: NavigationError.wrongTarget) { try ScreenD.navigationRegistration.resolver(issues, context) }
    }

    @Test("Screen C carries its compose prompt in the route")
    func screenCCompose() {
        let request = ScreenCNavigationContract.compose(prompt: "Hi")
        #expect(request.target == .screenC)
        #expect(request.route(as: ScreenCNavigationContract.Route.self) == .compose(prompt: "Hi"))
    }
}

@MainActor
private final class NavigatorStub: Navigator {
    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { $0.finish() } }
}
