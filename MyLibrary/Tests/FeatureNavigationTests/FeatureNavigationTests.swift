import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import ScreenBNavigationContract
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
    @Test("Issues maps each intent to its route")
    func issuesRoutes() throws {
        let issue = EntityRef(target: .issues, id: "abc", title: "")
        #expect(try Issues.route(for: NavigationRequest(intent: .browse(.issues))) == .list)
        #expect(try Issues.route(for: NavigationRequest(intent: .selectSingle(.issues))) == .picker)
        #expect(try Issues.route(for: NavigationRequest(intent: .open(issue))) == .details(id: "abc"))
        #expect(try Issues.route(for: NavigationRequest(intent: .screen(.issues, name: "detail/abc"))) == .listDetails(id: "abc"))
        #expect(try Issues.route(for: NavigationRequest(intent: .screen(.issues, name: "random"))) == .randomDetails)
        #expect(throws: NavigationError.unsupportedIntent) {
            try Issues.route(for: NavigationRequest(intent: .screen(.issues, name: "other")))
        }
    }

    @Test("Screen B maps its .b2 inner screen to B2, and other intents to home")
    func screenBRoutes() throws {
        #expect(try ScreenB.route(for: NavigationRequest(intent: .browse(.screenB))) == .home)
        #expect(try ScreenB.route(for: ScreenBNavigationContract.request(for: .b2)) == .b2)
        #expect(throws: NavigationError.unsupportedIntent) {
            try ScreenB.route(for: NavigationRequest(intent: .screen(.screenB, name: "b3")))
        }
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
}
