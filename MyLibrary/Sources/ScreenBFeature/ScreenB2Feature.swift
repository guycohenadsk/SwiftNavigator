import ComposableArchitecture
import NavigationCore
import IssuesNavigationContract
import NavigatorDependency
import ScreenDNavigationContract

@Reducer
public struct ScreenB2Feature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case openIssuesTapped
        case openScreenDAsSheetTapped
    }

    @Dependency(\.navigator) var navigator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .openIssuesTapped:
                let navigator = navigator
                return .run { _ in await navigator.push(NavigationRequest(IssuesNavigationContract.Route.list)) }
            case .openScreenDAsSheetTapped:
                let navigator = navigator
                return .run { _ in await navigator.present(NavigationRequest(ScreenDNavigationContract.Route.home)) }
            }
        }
    }
}
