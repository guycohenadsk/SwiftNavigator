import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import RFINavigationContract
import Testing

@testable import RFIDomain

@MainActor
@Suite("RFI list", .serialized)
struct RFIListTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeStore(_ navigator: NavigatorSpy, isPicker: Bool = false) -> TestStoreOf<RFIList> {
        withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.uuid = .incrementing
            $0.date = .constant(Self.now)
            $0.navigator = navigator
        } operation: {
            @Shared(.rfis) var rfis
            $rfis.withLock { $0 = RFIItem.seed }
            return TestStore(initialState: RFIList.State(isPicker: isPicker)) { RFIList() }
        }
    }

    @Test("Tapping a row pushes the standalone detail of that RFI")
    func tapPushes() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let rfi = store.state.rfis[1]

        await store.send(.rfiTapped(rfi.id))
        await store.finish()
        #expect(navigator.pushed == [NavigationRequest(RFINavigationContract.Route.open(id: rfi.id.uuidString))])
        #expect(navigator.completed.isEmpty)
    }

    @Test("Add appends a draft RFI and pushes its detail")
    func addOpensNewRFI() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let new = RFIItem(id: UUID(0), status: .draft, createdAt: Self.now)

        await store.send(.addRFITapped) {
            $0.$rfis.withLock { $0.append(new) }
        }
        await store.finish()
        #expect(navigator.pushed == [NavigationRequest(RFINavigationContract.Route.open(id: new.id.uuidString))])
        #expect(store.state.rfis.last == new)
    }

    @Test("In picker mode a tap completes with the RFI's reference and pushes nothing")
    func pickerCompletes() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator, isPicker: true)
        let rfi = store.state.rfis[0]

        await store.send(.rfiTapped(rfi.id))
        await store.finish()
        #expect(navigator.pushed.isEmpty)
        #expect(navigator.completed == [.selectedEntity(RFI.ref(for: rfi))])
    }

    @Test("Swipe-delete removes the rows and pushes nothing")
    func swipeDelete() async {
        let navigator = NavigatorSpy()
        let store = makeStore(navigator)
        let removed = [store.state.rfis[0].id, store.state.rfis[2].id]

        await store.send(.deleteRFIs([0, 2])) {
            $0.$rfis.withLock { $0.remove(atOffsets: [0, 2]) }
        }
        #expect(removed.allSatisfy { store.state.rfis[id: $0] == nil })
        #expect(navigator.pushed.isEmpty)
    }
}

@Suite("RFI model")
struct RFIItemTests {
    @Test("The row title is zero-padded, or New / Untitled when there is no number or subject")
    func rowTitle() {
        #expect(RFIItem(number: 7, subject: "Slab").rowTitle == "RFI-007  -  Slab")
        #expect(RFIItem(number: 123, subject: "Slab").rowTitle == "RFI-123  -  Slab")
        #expect(RFIItem().rowTitle == "New  -  Untitled")
        #expect(RFIItem(number: 0, subject: "Slab").rowTitle == "New  -  Slab")
    }
}
