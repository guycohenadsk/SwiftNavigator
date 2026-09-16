import AppRoutes
import ComposableArchitecture
import NavigatorDependency

@Reducer
public struct ScreenBFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var screenB2: ScreenB2Feature.State?

        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case pushScreenB2Tapped
        case screenB2(PresentationAction<ScreenB2Feature.Action>)
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .navigateButtonTapped(route):
                let navigator = navigator
                return .run { _ in await navigator.push(route) }
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
