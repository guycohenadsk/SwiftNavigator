import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import RFINavigationContract
import SwiftUI
import Testing
import UIKit

@testable import RFIDomain

/// A route of another module, to resolve through the RFI registration.
private enum OtherRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case list
}

@MainActor
@Suite("RFI navigation registration", .serialized)
struct RFINavigationRegistrationTests {
    private let registration = RFI.navigationRegistration
    private let navigator = NavigatorSpy()

    private func route(path: [String] = [], query: [String: String] = [:]) -> RFINavigationContract.Route? {
        registration.deepLink(DeepLink(target: .rfi, path: path, query: query))?.route(as: RFINavigationContract.Route.self)
    }

    private func resolve(_ request: NavigationRequest) throws -> UIViewController {
        let navigator = navigator
        return try withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = navigator
        } operation: {
            @Shared(.rfis) var rfis
            $rfis.withLock { $0 = RFIItem.seed }
            return try registration.resolver(request, NavigationContext(navigator: navigator, parent: nil, onLeave: { _ in }))
        }
    }

    @Test("`rfi` is the list, `rfi/<id>` the RFI; anything with an action is nil")
    func grammar() {
        #expect(registration.target == .rfi)
        #expect(route() == .list)
        #expect(route(path: ["abc"]) == .open(id: "abc"))
        #expect(route(query: ["action": "x"]) == nil)
    }

    @Test("No route is handed to a root screen")
    func toRoot() {
        for route: RFINavigationContract.Route in [.list, .pick, .open(id: "abc")] {
            #expect(!registration.deepLinksToRoot(NavigationRequest(route)))
        }
    }

    @Test("The list and the picker resolve to the list, the picker in picker mode")
    func listAndPicker() throws {
        let list = try #require(try resolve(NavigationRequest(RFINavigationContract.Route.list)) as? RFIListHostingController)
        #expect(!list.store.isPicker)
        let picker = try #require(try resolve(NavigationRequest(RFINavigationContract.Route.pick)) as? RFIListHostingController)
        #expect(picker.store.isPicker)
    }

    @Test("`.open` of a stored RFI is its detail; an unknown id is a placeholder")
    func open() throws {
        let stored = RFIItem.seed[0].id.uuidString
        #expect(try resolve(NavigationRequest(RFINavigationContract.Route.open(id: stored))) is UIHostingController<RFIDetailView>)
        #expect(!(try resolve(NavigationRequest(RFINavigationContract.Route.open(id: "nope"))) is UIHostingController<RFIDetailView>))
        #expect(!(try resolve(NavigationRequest(RFINavigationContract.Route.open(id: UUID().uuidString))) is UIHostingController<RFIDetailView>))
    }

    @Test("A route of another module is rejected")
    func wrongTarget() {
        #expect(throws: NavigationError.self) {
            try resolve(NavigationRequest(OtherRoute.list))
        }
    }

    @Test("A reference to an RFI carries its row title and the request that opens it")
    func reference() {
        let rfi = RFIItem.seed[0]
        let ref = RFI.ref(for: rfi)
        #expect(ref.id == rfi.id.uuidString)
        #expect(ref.title == rfi.rowTitle)
        #expect(ref.open == NavigationRequest(RFINavigationContract.Route.open(id: rfi.id.uuidString)))
    }
}

@MainActor
@Suite("RFI detail screen", .serialized)
struct RFIDetailScreenTests {
    @Test("Edits write through to storage; delete removes the RFI and completes with .dismissed")
    func editAndDelete() async {
        let navigator = NavigatorSpy()
        let (store, rfis) = withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.navigator = navigator
        } operation: {
            @Shared(.rfis) var rfis
            $rfis.withLock { $0 = RFIItem.seed }
            let rfi = Shared($rfis[id: RFIItem.seed[0].id])!
            let store = TestStore(initialState: RFIDetailScreen.State(rfi: rfi)) { RFIDetailScreen() }
            return (store, $rfis)
        }
        let id = store.state.detail.rfi.id

        await store.send(.detail(.subjectChanged("Renamed"))) {
            $0.detail.$rfi.withLock { $0.subject = "Renamed" }
        }
        #expect(rfis.wrappedValue[id: id]?.subject == "Renamed")

        await store.send(.detail(.delegate(.deleteRequested)))
        await store.finish()
        #expect(rfis.wrappedValue[id: id] == nil)
        #expect(navigator.completed == [.dismissed])
    }
}
