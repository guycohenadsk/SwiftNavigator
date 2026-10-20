import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import ScreenCNavigationContract

@Reducer
public struct IssuesList {
    @ObservableState
    public struct State: Equatable {
        /// Persisted to `Documents/issues.json`. The detail screen edits elements of this same
        /// array through a derived `Shared<Issue>`, so its edits land here — and on disk —
        /// without any save action travelling back.
        @Shared(.issues) public var issues: IdentifiedArrayOf<Issue>
        @Presents public var detail: IssuesDetail.State?
        /// Picker mode: tapping a row reports the issue to whoever opened the picker.
        public var isPicker: Bool
        /// The last text Screen C sent back from compose mode.
        public var screenCText: String?
        /// Whether this list already listens for the Issues deep-link actions — once per list, from
        /// its first appearance.
        var isListeningForDeepLinks = false

        public init(isPicker: Bool = false) {
            self.isPicker = isPicker
        }
    }

    public enum Action {
        case onAppear
        case pushTapped(NavigationTarget)
        case presentTapped(NavigationTarget)
        case pushScreenCWithContextTapped
        case issueTapped(Issue.ID)
        case addIssueTapped
        case deleteIssues(IndexSet)
        case detail(PresentationAction<IssuesDetail.Action>)
        case screenC(ScreenCNavigationContract.Output)
        /// A deep link's `?action=<name>`, delivered to the list at the root of the Issues tab.
        case deepLinkAction(String)
    }

    @Dependency(\.navigator) var navigator
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isPicker, !state.isListeningForDeepLinks else { return .none }
                state.isListeningForDeepLinks = true
                let navigator = navigator
                return .run { send in
                    for await action in await navigator.performedActions(for: .issues) {
                        await send(.deepLinkAction(action))
                    }
                }

            case .deepLinkAction(Issues.screenCContextAction):
                return pushScreenCWithContext()

            case .deepLinkAction:
                return .none

            case let .pushTapped(target):
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(intent: .browse(target))) }

            case let .presentTapped(target):
                let navigator = navigator
                return .run { _ in await navigator.present(NavigationRequest(intent: .browse(target))) }

            case .pushScreenCWithContextTapped:
                return pushScreenCWithContext()

            case let .issueTapped(id):
                if state.isPicker {
                    guard let issue = state.issues[id: id] else { return .none }
                    let picked = EntityRef(target: .issues, id: issue.id.uuidString, title: issue.rowTitle)
                    let navigator = navigator
                    return .run { _ in await navigator.complete(with: .selectedEntity(picked)) }
                }
                return open(id, in: &state)

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

    /// Pushes Screen C in compose mode; every text it sends comes back as a `.screenC` action. Ends
    /// when Screen C leaves.
    private func pushScreenCWithContext() -> Effect<Action> {
        let navigator = navigator
        return .run { send in
            let request = ScreenCNavigationContract.compose(prompt: "I have been pushed from the issues list")
            for await output in await navigator.pushForOutputs(request, as: ScreenCNavigationContract.Output.self) {
                await send(.screenC(output))
            }
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
