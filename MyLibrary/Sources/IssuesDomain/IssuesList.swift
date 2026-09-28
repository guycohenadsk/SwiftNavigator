import AppRoutes
import ComposableArchitecture
import Foundation
import NavigatorDependency

@Reducer
public struct IssuesList {
    @ObservableState
    public struct State: Equatable {
        /// Persisted to `Documents/issues.json`. The detail screen edits elements of this same
        /// array through a derived `Shared<Issue>`, so its edits land here — and on disk —
        /// without any save action travelling back.
        @Shared(.issues) public var issues: IdentifiedArrayOf<Issue>
        @Presents public var detail: IssuesDetail.State?
        /// Text handed back by Screen C through its context closure — the cross-module delegate demo.
        public var screenCText: String?

        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case presentButtonTapped(Route)
        case pushScreenCWithContextTapped
        case issueTapped(Issue.ID)
        case addIssueTapped
        case deleteIssues(IndexSet)
        case detail(PresentationAction<IssuesDetail.Action>)
        case screenC(ScreenCOutput)
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .navigateButtonTapped(route):
                let navigator = navigator
                return .run { _ in await navigator.push(route) }

            case let .presentButtonTapped(route):
                let navigator = navigator
                return .run { _ in await navigator.present(route) }

            case .pushScreenCWithContextTapped:
                let navigator = navigator
                return .run { send in
                    // The continuation lives only inside the context's output closure, which
                    // travels with the pushed RouteEntry. When Screen C is popped the entry — and
                    // with it the closure and continuation — deallocates, the stream finishes,
                    // and this effect completes on its own.
                    let outputs = AsyncStream<ScreenCOutput> { continuation in
                        let context = ScreenCContext(
                            subtitle: "I have been pushed from the issues list",
                            output: { continuation.yield($0) }
                        )
                        Task { await navigator.push(.screenC(context)) }
                    }
                    for await output in outputs {
                        await send(.screenC(output))
                    }
                }

            case let .issueTapped(id):
                return open(id, in: &state)

            case .addIssueTapped:
                let issue = Issue(status: .draft)
                state.$issues.withLock { $0.append(issue) }
                return open(issue.id, in: &state)

            case let .deleteIssues(offsets):
                state.$issues.withLock { $0.remove(atOffsets: offsets) }
                return .none

            case .detail(.presented(.delegate(.deleteRequested))):
                guard let id = state.detail?.issue.id else { return .none }
                state.detail = nil
                state.$issues.withLock { $0.remove(id: id) }
                return .none

            case .detail:
                return .none

            case let .screenC(.textSubmitted(text)):
                state.screenCText = text
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            IssuesDetail()
        }
    }

    /// Derives a `Shared<Issue>` pointing *into* the persisted array, so the detail screen edits
    /// the stored issue rather than a detached copy.
    private func open(_ id: Issue.ID, in state: inout State) -> Effect<Action> {
        guard let issue = Shared(state.$issues[id: id]) else { return .none }
        state.detail = IssuesDetail.State(issue: issue)
        return .none
    }
}
