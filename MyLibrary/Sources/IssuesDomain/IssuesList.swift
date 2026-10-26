import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import ScreenCNavigationContract

@Reducer
public struct IssuesList {
    @ObservableState
    public struct State: Equatable {
        /// Persisted to `Documents/issues.json`. The list's detail works on a copy and reports its
        /// edits and deletion as `.detail` actions; the list applies them here.
        @Shared(.issues) public var issues: IdentifiedArrayOf<Issue>
        /// Picker mode: tapping a row reports the issue to whoever opened the picker.
        public var isPicker: Bool
        /// The last text Screen C sent back from compose mode.
        public var screenCText: String?
        /// Whether this list already listens for Issues deep links — once per list, from its first
        /// appearance.
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
        /// An update from the detail the list pushed.
        case detail(IssuesDetail.Output)
        case screenC(ScreenCNavigationContract.Output)
        /// A deep link delivered to the list at the root of the Issues tab: an issue to open
        /// (`demoapp://issues/<id>`), or an action (`?action=<name>`).
        case incomingRequest(NavigationRequest)
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
                    for await request in await navigator.incomingRequests(for: .issues) {
                        await send(.incomingRequest(request))
                    }
                }

            case let .incomingRequest(request):
                switch request.intent {
                case let .open(ref):
                    // An unknown or deleted issue leaves the list as it is.
                    guard let id = UUID(uuidString: ref.id) else { return .none }
                    return open(id, in: state)
                case .perform(_, Issues.screenCContextAction):
                    return pushScreenCWithContext()
                default:
                    return .none
                }

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
                    let picked = Issues.ref(for: issue)
                    let navigator = navigator
                    return .run { _ in await navigator.complete(with: .selectedEntity(picked)) }
                }
                return open(id, in: state)

            case .addIssueTapped:
                let issue = Issue(id: uuid(), status: .draft, createdAt: now)
                state.$issues.withLock { $0.append(issue) }
                return open(issue.id, in: state)

            case let .deleteIssues(offsets):
                state.$issues.withLock { $0.remove(atOffsets: offsets) }
                return .none

            case let .detail(.edited(issue)):
                // Only issues still stored: an edit must not bring back a deleted one.
                state.$issues.withLock { issues in
                    if issues[id: issue.id] != nil { issues[id: issue.id] = issue }
                }
                return .none

            case let .detail(.deleteRequested(id)):
                _ = state.$issues.withLock { $0.remove(id: id) }
                return .none

            case let .screenC(.textSubmitted(text)):
                state.screenCText = text
                return .none
            }
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

    /// Pushes the detail through the navigator, which builds it from the request. The list keeps no
    /// state of it: every edit and the delete come back as `.detail` actions until it leaves.
    private func open(_ id: Issue.ID, in state: State) -> Effect<Action> {
        guard let issue = state.issues[id: id] else { return .none }
        let navigator = navigator
        return .run { send in
            let request = Issues.detailRequest(for: issue)
            for await output in await navigator.pushForOutputs(request, as: IssuesDetail.Output.self) {
                await send(.detail(output))
            }
        }
    }
}
