import AppRoutes
import ComposableArchitecture
import NavigatorDependency

@Reducer
public struct ScreenAFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var screenA2: ScreenA2Feature.State?

        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case presentButtonTapped(Route)
        case pushScreenA2Tapped
        case screenA2(PresentationAction<ScreenA2Feature.Action>)
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
            case .pushScreenA2Tapped:
                state.screenA2 = ScreenA2Feature.State()
                return .none
            case .screenA2:
                return .none
            }
        }
        .ifLet(\.$screenA2, action: \.screenA2) {
            ScreenA2Feature()
        }
    }
}
