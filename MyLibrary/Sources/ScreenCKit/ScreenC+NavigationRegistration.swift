import NavigationCore
import ScreenCNavigationContract

extension ScreenC {
    public static let navigationRegistration = NavigationRegistration(
        ScreenCNavigationContract.Route.self,
        deepLink: { link in link.path.isEmpty && link.query.isEmpty ? .home : nil },
        resolver: { route, context in
            switch route {
            case .home: ScreenCViewController(navigator: context.navigator)
            case let .compose(prompt): ScreenCViewController(navigator: context.navigator, prompt: prompt)
            }
        }
    )
}
