import ComposableArchitecture
import NavigationCore
import ScreenBNavigationContract

extension ScreenB {
    public static let navigationRegistration = NavigationRegistration(
        target: ScreenBNavigationContract.target,
        resolver: { request, _ in
            switch try route(for: request) {
            case .home:
                ScreenBHostingController(store: Store(initialState: ScreenBFeature.State()) { ScreenBFeature() })
            }
        }
    )

    static func route(for request: NavigationRequest) throws -> ScreenBNavigationContract.Route {
        guard request.target == ScreenBNavigationContract.target else { throw NavigationError.wrongTarget }
        return .home
    }
}
