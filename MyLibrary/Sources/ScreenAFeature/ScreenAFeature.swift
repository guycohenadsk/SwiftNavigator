import AppRoutes
import ComposableArchitecture
import NavigatorDependency

@Reducer
public struct ScreenAFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents public var screenA2: ScreenA2Feature.State?
        public var screenCText: String?

        public init() {}
    }

    public enum Action {
        case navigateButtonTapped(Route)
        case presentButtonTapped(Route)
        case pushScreenA2Tapped
        case pushScreenCWithContextTapped
        case screenA2(PresentationAction<ScreenA2Feature.Action>)
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
            case .pushScreenA2Tapped:
                state.screenA2 = ScreenA2Feature.State()
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
                            subtitle: "I have been pushed from Screen A",
                            output: { continuation.yield($0) }
                        )
                        Task { await navigator.push(.screenC(context)) }
                    }
                    for await output in outputs {
                        await send(.screenC(output))
                    }
                }
            case .screenA2:
                return .none
            case let .screenC(.textSubmitted(text)):
                state.screenCText = text
                return .none
            }
        }
        .ifLet(\.$screenA2, action: \.screenA2) {
            ScreenA2Feature()
        }
    }
}
