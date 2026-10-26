import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract

@Reducer
public struct ScreenBFeature {
    @ObservableState
    public struct State: Equatable {
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
                // Screen B keeps no state of B2: the navigator builds it from the request.
                let navigator = navigator
                return .run { _ in await navigator.push(ScreenBNavigationContract.request(for: .b2)) }
            }
        }
    }
}
