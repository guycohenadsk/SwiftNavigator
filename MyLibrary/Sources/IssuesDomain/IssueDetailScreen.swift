import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency

/// Issue details as the navigator builds them from an `.open` request, owning their own state.
///
/// Opened by another module (Screen B, C, D, RefPicker), nobody owns the detail, so it edits the
/// stored issue directly and deletes it itself. The Issues list's own detail is its child instead
/// (`IssuesList.State.detail`).
@Reducer
struct IssueDetailScreen {
    @ObservableState
    struct State: Equatable {
        var detail: IssuesDetail.State

        init(issue: Shared<Issue>) {
            self.detail = IssuesDetail.State(issue: issue)
        }
    }

    enum Action {
        case detail(IssuesDetail.Action)
    }

    @Dependency(\.navigator) var navigator

    var body: some ReducerOf<Self> {
        Scope(state: \.detail, action: \.detail) {
            IssuesDetail()
        }
        Reduce { state, action in
            switch action {
            case .detail(.delegate(.deleteRequested)):
                let id = state.detail.issue.id
                @Shared(.issues) var issues
                $issues.withLock { _ = $0.remove(id: id) }
                let navigator = navigator
                return .run { _ in await navigator.complete(with: .dismissed) }
            case .detail:
                return .none
            }
        }
    }
}
