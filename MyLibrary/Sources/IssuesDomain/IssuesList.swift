import AppRoutes
import ComposableArchitecture
import NavigatorDependency

@Reducer
public struct IssuesList {
    @ObservableState
    public struct State: Equatable {
        @Presents public var detail: IssuesDetail.State?
        public var screenCText: String?

        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case presentButtonTapped(Route)
        case pushDetailTapped
        case pushScreenCWithContextTapped
        case detail(PresentationAction<IssuesDetail.Action>)
        case screenC(ScreenCOutput)
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
            case .pushDetailTapped:
                state.detail = IssuesDetail.State()
                return .none
            case .pushScreenCWithContextTapped:
                let navigator = navigator
                return .run { send in
                    // The continuation lives only inside the context's output closure, which
                    // travels with the pushed RouteEntry. When Screen C is popped the entry — and
                    // with it the closure and continuation — deallocates, the stream finishes,
                    // and this effect completes on its own.
                    let outputs = AsyncStream<ScreenCOutput> { continuation in
                        let context = ScreenCContext(
                            subtitle: "I have been pushed from Issues",
                            output: { continuation.yield($0) }
                        )
                        Task { await navigator.push(.screenC(context)) }
                    }
                    for await output in outputs {
                        await send(.screenC(output))
                    }
                }
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
}
