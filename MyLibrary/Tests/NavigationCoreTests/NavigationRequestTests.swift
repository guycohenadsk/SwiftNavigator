import Foundation
import NavigationCore
import Testing

private enum RouteA: NavigationRoute {
    static let target = NavigationTarget.issues
    case list
    case open(id: String)
}

private enum RouteB: NavigationRoute {
    static let target = NavigationTarget.screenB
    case home
}

/// Same shape and target as `RouteA`, but another type.
private enum LookalikeRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case list
}

@Suite("NavigationRequest")
struct NavigationRequestTests {
    @Test("Target comes from the route's type")
    func target() {
        #expect(NavigationRequest(RouteA.open(id: "1")).target == .issues)
        #expect(NavigationRequest(RouteB.home).target == .screenB)
    }

    @Test("Requests are equal when the route is")
    func equality() {
        #expect(NavigationRequest(RouteA.open(id: "1")) == NavigationRequest(RouteA.open(id: "1")))
        #expect(NavigationRequest(RouteA.open(id: "1")) != NavigationRequest(RouteA.open(id: "2")))
        #expect(NavigationRequest(RouteA.list) != NavigationRequest(RouteB.home))
        #expect(NavigationRequest(RouteA.list) != NavigationRequest(LookalikeRoute.list))
    }

    @Test("Equal requests hash alike")
    func hashing() {
        let set: Set = [NavigationRequest(RouteA.open(id: "1")), NavigationRequest(RouteA.open(id: "1")), NavigationRequest(RouteB.home)]
        #expect(set.count == 2)
    }

    @Test("The route reads back only as its own type")
    func routeAs() {
        let request = NavigationRequest(RouteA.open(id: "1"))
        #expect(request.route(as: RouteA.self) == .open(id: "1"))
        #expect(request.route(as: RouteB.self) == nil)
        #expect(request.route(as: LookalikeRoute.self) == nil)
    }
}

@Suite("NavigationResult")
struct NavigationResultTests {
    @Test("Only .output is an update; everything else ends the handler")
    func finality() {
        #expect(!NavigationResult.output(NavigationOutput("hi")).isFinal)
        #expect(NavigationResult.dismissed.isFinal)
        #expect(NavigationResult.selectedEntity(EntityRef(id: "1", title: "", open: NavigationRequest(RouteA.list))).isFinal)
    }

    @Test("An output reads back only as the type it was sent as")
    func typedOutput() {
        let result = NavigationResult.output(NavigationOutput(42))
        #expect(result.output(as: Int.self) == 42)
        #expect(result.output(as: String.self) == nil)
        #expect(NavigationResult.dismissed.output(as: Int.self) == nil)
        #expect(NavigationOutput(42) == NavigationOutput(42))
        #expect(NavigationOutput(42) != NavigationOutput("42"))
    }
}
