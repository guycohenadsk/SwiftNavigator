import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency

/// The Issues list as a TCA parent of its detail: the detail's state lives here (`@Presents` +
/// `.ifLet`), its store is scoped from this one, and its screen is pushed through the navigator.
/// The reducer does both halves together — it sets `detail` and pushes the detail's request — and
/// `IssuesScopeListHostingController` builds the screen from the scoped store when the push lands.
///
/// The screen only ever leaves through the navigator. Back, swipe-back or a deep-link reset arrive as
/// `.detail(.dismiss)` (sent by `provideChild`) and clear the state; when the list clears it itself
/// (delete), it pops the screen. The detail never uses `\.dismiss`.
@Reducer
public struct IssuesScopeList {
    @ObservableState
    public struct State: Equatable {
        @Presents public var detail: IssuesDetail.State?
        /// Whether this list already listens for its deep links — once per list, from its first
        /// appearance.
        var isListeningForDeepLinks = false
        /// The same persisted issues as the Issues tab. The detail edits an element through a
        /// derived `Shared<Issue>`, so its edits land here without any action travelling back.
        @Shared(.issues) public var issues: IdentifiedArrayOf<Issue>

        public init() {}
    }

    public enum Action {
        case addIssueTapped
        case deleteIssues(IndexSet)
        case detail(PresentationAction<IssuesDetail.Action>)
        /// A deep link delivered to the list at the root of its tab (`demoapp://issues-scope/<id>`).
        case incomingRequest(NavigationRequest)
        case issueTapped(Issue.ID)
        case onAppear
    }

    @Dependency(\.date.now) var now
    @Dependency(\.navigator) var navigator
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addIssueTapped:
                let issue = Issue(id: uuid(), status: .draft, createdAt: now)
                state.$issues.withLock { $0.append(issue) }
                return open(issue.id, in: &state)

            case let .deleteIssues(offsets):
                state.$issues.withLock { $0.remove(atOffsets: offsets) }
                return .none

            case .detail(.presented(.delegate(.deleteRequested))):
                guard let id = state.detail?.issue.id else { return .none }
                state.detail = nil
                _ = state.$issues.withLock { $0.remove(id: id) }
                // The screen leaves the way it came, through the navigator.
                let navigator = navigator
                return .run { _ in await navigator.pop() }

            case .detail: // Whatever I want
                return .none

            case let .incomingRequest(request):
                // An unknown or deleted issue leaves the list as it is.
                guard case let .open(ref) = request.intent, let id = UUID(uuidString: ref.id) else { return .none }
                return open(id, in: &state)

            case let .issueTapped(id):
                return open(id, in: &state)

            case .onAppear:
                guard !state.isListeningForDeepLinks else { return .none }
                state.isListeningForDeepLinks = true
                let navigator = navigator
                return .run { send in
                    for await request in await navigator.incomingRequests(for: .issuesScope) {
                        await send(.incomingRequest(request))
                    }
                }
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            IssuesDetail()
        }
    }

    /// Sets the detail's state and pushes its request. The detail edits the stored issue through a
    /// `Shared<Issue>` pointing into the array.
    private func open(_ id: Issue.ID, in state: inout State) -> Effect<Action> {
        guard let issue = Shared(state.$issues[id: id]) else { return .none }
        state.detail = IssuesDetail.State(issue: issue)
        let navigator = navigator
        let request = Issues.scopeDetailRequest(for: issue.wrappedValue)
        return .run { _ in await navigator.push(request) }
    }
}
