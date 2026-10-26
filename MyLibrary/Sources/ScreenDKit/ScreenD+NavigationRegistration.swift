import NavigationCore
import ScreenDNavigationContract

extension ScreenD {
    public static let navigationRegistration = NavigationRegistration(
        target: ScreenDNavigationContract.target,
        resolver: { request, context in
            switch try route(for: request) {
            case .home: ScreenDViewController(navigator: context.navigator)
            }
        }
    )

    static func route(for request: NavigationRequest) throws -> ScreenDNavigationContract.Route {
        guard request.target == ScreenDNavigationContract.target else { throw NavigationError.wrongTarget }
        return .home
    }
}
