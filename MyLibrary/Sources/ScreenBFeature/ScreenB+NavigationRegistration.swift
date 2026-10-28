import ComposableArchitecture
import NavigationCore
import ScreenBNavigationContract
import SwiftUI

extension ScreenB {
    public static let navigationRegistration = NavigationRegistration(
        target: ScreenBNavigationContract.target,
        resolver: { request, _ in
            switch try route(for: request) {
            case .home:
                UIHostingController(rootView: ScreenBView(store: Store(initialState: ScreenBFeature.State()) { ScreenBFeature() }))
            case .b2:
                UIHostingController(rootView: ScreenB2View(store: Store(initialState: ScreenB2Feature.State()) { ScreenB2Feature() }))
            }
        }
    )

    static func route(for request: NavigationRequest) throws -> ScreenBNavigationContract.Route {
        guard request.target == ScreenBNavigationContract.target else { throw NavigationError.wrongTarget }
        if case let .screen(_, name) = request.intent {
            guard ScreenBNavigationContract.Screen(rawValue: name) == .b2 else { throw NavigationError.unsupportedIntent }
            return .b2
        }
        return .home
    }
}
