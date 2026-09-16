import AppRoutes
import ComposableArchitecture
import NavigatorDependency

@Reducer
public struct ScreenB2Feature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case let .navigateButtonTapped(route):
                let navigator = navigator
                return .run { _ in await navigator.push(route) }
            }
        }
    }
}
