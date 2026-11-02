import ComposableArchitecture
import Foundation
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import ScreenCNavigationContract

/// The Issues list as a TCA parent of its detail: the detail's state lives here (`@Presents` +
/// `.ifLet`), its store is scoped from this one, and its screen is pushed through the navigator.
/// The reducer does both halves together — it sets `detail` and pushes the detail's request — and
/// the Issues registration builds the screen from the scoped store when the push lands.
///
/// The screen only ever leaves through the navigator. Back, swipe-back or a deep-link reset arrive as
/// `.detail(.dismiss)` (sent by `NavigationContext.child`) and clear the state; when the list clears
/// it itself (delete), it pops the screen. The detail never uses `\.dismiss`.
///
/// Screen C, a UIKit screen behind its contract, is the other way round: the list keeps no state of
/// it and hears back through typed outputs (`pushForOutputs`).
@Reducer
public struct IssuesList {
    @ObservableState
    public struct State: Equatable {
        @Presents public var detail: IssuesDetail.State?
        /// Picker mode: tapping a row reports the issue to whoever opened the picker.
        public var isPicker: Bool
        /// Whether this list already listens for Issues deep links — once per list, from its first
        /// appearance.
        var isListeningForDeepLinks = false
        /// Persisted to `Documents/issues.json`. The detail edits an element through a derived
        /// `Shared<Issue>`, so its edits land here without any action travelling back.
        @Shared(.issues) public var issues: IdentifiedArrayOf<Issue>
        /// The last text Screen C sent back from compose mode.
        public var screenCText: String?

        public init(isPicker: Bool = false) {
            self.isPicker = isPicker
        }
    }

    public enum Action {
        case addIssueTapped
        case deleteIssues(IndexSet)
        case detail(PresentationAction<IssuesDetail.Action>)
        /// A deep link delivered to the list at the root of the Issues tab: an issue to open
        /// (`demoapp://issues/<id>`), or Screen C with context (`?action=screenCContext`).
        case incomingRequest(NavigationRequest)
        case issueTapped(Issue.ID)
        case onAppear
        case presentTapped(NavigationRequest)
        case pushScreenCWithContextTapped
        case pushTapped(NavigationRequest)
        case randomIssueTapped
        case screenC(ScreenCNavigationContract.Output)
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

            case .detail:
                return .none

            case let .incomingRequest(request):
                switch request.route(as: IssuesNavigationContract.Route.self) {
                case let .open(rawID):
                    // An unknown or deleted issue leaves the list as it is.
                    guard let id = UUID(uuidString: rawID) else { return .none }
                    return open(id, in: &state)
                case .screenCContext:
                    return pushScreenCWithContext()
                default:
                    return .none
                }

            case let .issueTapped(id):
                if state.isPicker {
                    guard let issue = state.issues[id: id] else { return .none }
                    let picked = Issues.ref(for: issue)
                    let navigator = navigator
                    return .run { _ in await navigator.complete(with: .selectedEntity(picked)) }
                }
                return open(id, in: &state)

            case .onAppear:
                guard !state.isPicker, !state.isListeningForDeepLinks else { return .none }
                state.isListeningForDeepLinks = true
                let navigator = navigator
                return .run { send in
                    for await request in await navigator.incomingRequests(for: .issues) {
                        await send(.incomingRequest(request))
                    }
                }

            case let .presentTapped(request):
                let navigator = navigator
                return .run { _ in await navigator.present(request) }

            case .pushScreenCWithContextTapped:
                return pushScreenCWithContext()

            case let .pushTapped(request):
                let navigator = navigator
                return .run { _ in await navigator.push(request) }

            case .randomIssueTapped:
                // Not the list's child: the navigator builds a standalone detail of a random issue.
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(IssuesNavigationContract.Route.random)) }

            case let .screenC(.textSubmitted(text)):
                state.screenCText = text
                return .none
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
        let request = Issues.detailRequest(for: issue.wrappedValue)
        return .run { _ in await navigator.push(request) }
    }

    /// Pushes Screen C in compose mode; every text it sends comes back as a `.screenC` action. Ends
    /// when Screen C leaves.
    private func pushScreenCWithContext() -> Effect<Action> {
        let navigator = navigator
        return .run { send in
            let request = NavigationRequest(ScreenCNavigationContract.Route.compose(prompt: "I have been pushed from the issues list"))
            for await output in await navigator.pushForOutputs(request, as: ScreenCNavigationContract.Output.self) {
                await send(.screenC(output))
            }
        }
    }
}
