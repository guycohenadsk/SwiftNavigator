import NavigationCore
import ScreenCNavigationContract

extension ScreenC {
    public static let navigationRegistration = NavigationRegistration(
        target: ScreenCNavigationContract.target,
        resolver: { request, navigator in
            switch try route(for: request) {
            case .home: ScreenCViewController(navigator: navigator)
            case let .compose(prompt): ScreenCViewController(navigator: navigator, prompt: prompt)
            }
        }
    )

    static func route(for request: NavigationRequest) throws -> ScreenCNavigationContract.Route {
        guard request.target == ScreenCNavigationContract.target else { throw NavigationError.wrongTarget }
        if case let .compose(_, prompt) = request.intent { return .compose(prompt: prompt) }
        return .home
    }
}
