import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency

/// An RFI's detail as the navigator builds it from an `.open` request, owning its own state: it
/// edits the stored RFI directly, and deletes it itself.
@Reducer
struct RFIDetailScreen {
    @ObservableState
    struct State: Equatable {
        var detail: RFIDetail.State

        init(rfi: Shared<RFIItem>) {
            self.detail = RFIDetail.State(rfi: rfi)
        }
    }

    enum Action {
        case detail(RFIDetail.Action)
    }

    @Dependency(\.navigator) var navigator

    var body: some ReducerOf<Self> {
        Scope(state: \.detail, action: \.detail) {
            RFIDetail()
        }
        Reduce { state, action in
            switch action {
            case .detail(.delegate(.deleteRequested)):
                let id = state.detail.rfi.id
                @Shared(.rfis) var rfis
                $rfis.withLock { _ = $0.remove(id: id) }
                let navigator = navigator
                return .run { _ in await navigator.complete(with: .dismissed) }
            case .detail:
                return .none
            }
        }
    }
}
