import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import Testing
import UIKit

@testable import IssuesDomain
@testable import ScreenBFeature
@testable import ScreenCKit
@testable import ScreenDKit

@MainActor
@Suite("Feature navigation")
struct FeatureNavigationTests {
    @Test("Issues maps each intent to its route")
    func issuesRoutes() throws {
        let issue = EntityRef(target: .issues, id: "abc", title: "")
        #expect(try Issues.route(for: NavigationRequest(intent: .browse(.issues))) == .list)
        #expect(try Issues.route(for: NavigationRequest(intent: .selectSingle(.issues))) == .picker)
        #expect(try Issues.route(for: NavigationRequest(intent: .open(issue))) == .details(id: "abc"))
    }

    @Test("Every module rejects requests addressed to another module")
    func wrongTarget() {
        let other = NavigationRequest(intent: .browse(.screenD))
        #expect(throws: NavigationError.wrongTarget) { try Issues.route(for: other) }
        #expect(throws: NavigationError.wrongTarget) { try ScreenB.route(for: other) }
        #expect(throws: NavigationError.wrongTarget) { try ScreenC.route(for: other) }
        #expect(throws: NavigationError.wrongTarget) { try ScreenD.route(for: NavigationRequest(intent: .browse(.issues))) }
    }

    @Test("Screen C maps .compose to compose mode and anything else to home")
    func screenCRoutes() throws {
        #expect(try ScreenC.route(for: NavigationRequest(intent: .compose(.screenC, prompt: "Hi"))) == .compose(prompt: "Hi"))
        #expect(try ScreenC.route(for: NavigationRequest(intent: .browse(.screenC))) == .home)
    }

    @Test("Issues does not take text or resolve actions as screens")
    func issuesRejectsComposeAndPerform() {
        #expect(throws: NavigationError.unsupportedIntent) {
            try Issues.route(for: NavigationRequest(intent: .compose(.issues, prompt: "Hi")))
        }
        #expect(throws: NavigationError.unsupportedIntent) {
            try Issues.route(for: NavigationRequest(intent: .perform(.issues, action: "screenCContext")))
        }
    }

    @Test("Issues declares the screenCContext deep-link action")
    func issuesDeclaresAction() {
        #expect(Issues.navigationRegistration.actions.keys.contains(Issues.screenCContextAction))
    }

    @Test("Opening an issue that does not exist shows a not-found screen, not a crash")
    func unknownIssue() {
        let controller = withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            Issues.viewController(for: .details(id: "not-a-uuid"))
        }
        #expect(!(controller is IssuesListHostingController))
    }
}
