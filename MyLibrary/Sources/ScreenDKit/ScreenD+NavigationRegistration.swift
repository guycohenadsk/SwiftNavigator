import NavigationCore
import ScreenDNavigationContract

extension ScreenD {
    public static let navigationRegistration = NavigationRegistration(
        ScreenDNavigationContract.Route.self,
        deepLink: { link in link.path.isEmpty && link.query.isEmpty ? .home : nil },
        resolver: { route, context in
            switch route {
            case .home: ScreenDViewController(navigator: context.navigator)
            }
        }
    )
}
