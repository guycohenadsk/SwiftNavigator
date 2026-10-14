import ComposableArchitecture
import NavigationCore
import NavigatorDependency

@Reducer
public struct ScreenBFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var screenB2: ScreenB2Feature.State?
        /// The issue picked through the Issues picker — a result travelling back across modules,
        /// with nothing shared but NavigationCore.
        public var linkedIssue: EntityRef?

        public init() {}
    }

    public enum Action {
        case linkIssueTapped
        case issueLinked(EntityRef)
        case openLinkedIssueTapped
        case openIssuesTapped
        case openScreenDTapped
        case pushScreenB2Tapped
        case screenB2(PresentationAction<ScreenB2Feature.Action>)
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .linkIssueTapped:
                let navigator = navigator
                return .run { send in
                    let result = await navigator.presentForResult(NavigationRequest(intent: .selectSingle(.issues)))
                    if case let .selectedEntity(issue) = result {
                        await send(.issueLinked(issue))
                    }
                }

            case let .issueLinked(issue):
                state.linkedIssue = issue
                return .none

            case .openLinkedIssueTapped:
                guard let issue = state.linkedIssue else { return .none }
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(intent: .open(issue))) }

            case .openIssuesTapped:
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(intent: .browse(.issues))) }

            case .openScreenDTapped:
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(intent: .browse(.screenD))) }

            case .pushScreenB2Tapped:
                state.screenB2 = ScreenB2Feature.State()
                return .none

            case .screenB2:
                return .none
            }
        }
        .ifLet(\.$screenB2, action: \.screenB2) {
            ScreenB2Feature()
        }
    }
}
