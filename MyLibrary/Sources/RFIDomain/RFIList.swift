import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import RFINavigationContract

/// The RFI list. It owns no detail state: opening an RFI pushes the standalone `.open(id:)`
/// detail, which edits the stored RFI itself. In picker mode a tap completes with the RFI.
@Reducer
public struct RFIList {
    @ObservableState
    public struct State: Equatable {
        /// Picker mode: tapping a row reports the RFI to whoever opened the picker.
        public var isPicker: Bool
        /// Persisted to `Documents/rfis.json`.
        @Shared(.rfis) public var rfis: IdentifiedArrayOf<RFIItem>

        public init(isPicker: Bool = false) {
            self.isPicker = isPicker
        }
    }

    public enum Action {
        case addRFITapped
        case deleteRFIs(IndexSet)
        case rfiTapped(RFIItem.ID)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.navigator) var navigator
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addRFITapped:
                let rfi = RFIItem(id: uuid(), status: .draft, createdAt: now)
                state.$rfis.withLock { $0.append(rfi) }
                return open(rfi.id)

            case let .deleteRFIs(offsets):
                state.$rfis.withLock { $0.remove(atOffsets: offsets) }
                return .none

            case let .rfiTapped(id):
                if state.isPicker {
                    guard let rfi = state.rfis[id: id] else { return .none }
                    let picked = RFI.ref(for: rfi)
                    let navigator = navigator
                    return .run { _ in await navigator.complete(with: .selectedEntity(picked)) }
                }
                return open(id)
            }
        }
    }

    private func open(_ id: RFIItem.ID) -> Effect<Action> {
        let navigator = navigator
        let request = NavigationRequest(RFINavigationContract.Route.open(id: id.uuidString))
        return .run { _ in await navigator.push(request) }
    }
}
