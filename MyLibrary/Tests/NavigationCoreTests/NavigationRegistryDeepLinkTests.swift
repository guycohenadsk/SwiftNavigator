import Foundation
import NavigationCore
import Testing
import UIKit

/// Test-local modules: the core knows none of them, a registration brings its own routes.
private enum IssueRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case list
    case open(id: String)
    case action(String)
}

private enum BRoute: NavigationRoute {
    static let target = NavigationTarget.screenB
    case home
}

@MainActor
private func makeRegistry() throws -> NavigationRegistry {
    let registry = NavigationRegistry()
    try registry.register(NavigationRegistration(
        IssueRoute.self,
        deepLink: { link in
            if let id = link.path.first { return .open(id: id) }
            if let action = link.query["action"] { return action.isEmpty ? nil : .action(action) }
            return .list
        },
        toRoot: { route in
            if case .open = route { true } else { false }
        },
        resolver: { _, _ in UIViewController() }
    ))
    try registry.register(NavigationRegistration(
        BRoute.self,
        deepLink: { $0.path.isEmpty ? .home : nil },
        resolver: { _, _ in UIViewController() }
    ))
    return registry
}

@MainActor
@Suite("NavigationRegistry deep links")
struct NavigationRegistryDeepLinkTests {
    private func request(_ string: String) throws -> NavigationRequest {
        try makeRegistry().request(for: #require(URL(string: string)))
    }

    @Test("A bare target is the module's own reading of it")
    func bareTarget() throws {
        #expect(try request("demoapp://issues") == NavigationRequest(IssueRoute.list))
        #expect(try request("demoapp://screenB") == NavigationRequest(BRoute.home))
    }

    @Test("The path is handed to the module")
    func path() throws {
        #expect(try request("demoapp://issues/issue-1") == NavigationRequest(IssueRoute.open(id: "issue-1")))
    }

    @Test("The query is handed to the module")
    func query() throws {
        #expect(try request("demoapp://issues?action=go") == NavigationRequest(IssueRoute.action("go")))
    }

    @Test("A link the module does not offer is unsupported")
    func unsupportedLink() throws {
        #expect(throws: DeepLinkError.unsupportedLink) { try request("demoapp://issues?action=") }
        #expect(throws: DeepLinkError.unsupportedLink) { try request("demoapp://screenB/extra") }
    }

    @Test("Another scheme is rejected")
    func wrongScheme() throws {
        #expect(throws: DeepLinkError.unsupportedScheme) { try request("https://issues/issue-1") }
    }

    @Test("An unknown target is rejected")
    func unknownTarget() throws {
        #expect(throws: DeepLinkError.unknownTarget) { try request("demoapp://nope") }
    }

    @Test("A known target nobody registered throws unregisteredTarget")
    func unregisteredTarget() throws {
        #expect(throws: NavigationError.unregisteredTarget(.screenD)) { try request("demoapp://screenD") }
    }

    @Test("deepLinksToRoot follows the module's toRoot")
    func toRoot() throws {
        let registry = try makeRegistry()
        #expect(registry.deepLinksToRoot(NavigationRequest(IssueRoute.open(id: "1"))))
        #expect(!registry.deepLinksToRoot(NavigationRequest(IssueRoute.list)))
        #expect(!registry.deepLinksToRoot(NavigationRequest(BRoute.home)))
    }
}
