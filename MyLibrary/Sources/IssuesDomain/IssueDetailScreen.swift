import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency

extension IssuesDetail {
    /// What the list's detail reports to the list, as `.output` updates while it stays up.
    @CasePathable
    public enum Output: Hashable, Sendable {
        /// The issue as it now reads, after every edit.
        case edited(Issue)
        /// The user confirmed deleting the issue; the detail closes itself right after.
        case deleteRequested(Issue.ID)
    }
}

/// Issue details as the navigator builds them from a request, owning their own state.
///
/// Pushed by the Issues list (`Issues.detailRequest(for:)`), it works on a copy and reports every
/// edit and the delete to the list through `IssuesDetail.Output`; the list applies them. Opened by
/// another module (Screen B, Screen C, RefPicker) with `.open`, nobody listens for outputs, so it
/// edits the stored issue and deletes it itself.
@Reducer
struct IssueDetailScreen {
    @ObservableState
    struct State: Equatable {
        var detail: IssuesDetail.State
        /// Whether whoever opened it applies its edits and deletion (the list), rather than it.
        let reportsToOpener: Bool
        /// The issue as last reported to the opener. `issue` is a `Shared`, so its old value can't
        /// be read back after an edit; this is what an edit is compared against.
        var reportedIssue: Issue

        init(issue: Shared<Issue>, reportsToOpener: Bool) {
            self.detail = IssuesDetail.State(issue: issue)
            self.reportsToOpener = reportsToOpener
            self.reportedIssue = issue.wrappedValue
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
                let navigator = navigator
                guard state.reportsToOpener else {
                    @Shared(.issues) var issues
                    $issues.withLock { _ = $0.remove(id: id) }
                    return .run { _ in await navigator.complete(with: .dismissed) }
                }
                return .run { _ in
                    await navigator.send(.output(NavigationOutput(IssuesDetail.Output.deleteRequested(id))))
                    await navigator.complete(with: .dismissed)
                }
            case .detail:
                // Any action that changed the issue is reported once, with the issue as it now reads.
                guard state.reportsToOpener, state.detail.issue != state.reportedIssue else { return .none }
                let issue = state.detail.issue
                state.reportedIssue = issue
                let navigator = navigator
                return .run { _ in await navigator.send(.output(NavigationOutput(IssuesDetail.Output.edited(issue)))) }
            }
        }
    }
}
