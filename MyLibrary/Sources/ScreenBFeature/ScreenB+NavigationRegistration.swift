import ComposableArchitecture
import NavigationCore
import ScreenBNavigationContract
import SwiftUI

extension ScreenB {
    public static let navigationRegistration = NavigationRegistration(
        ScreenBNavigationContract.Route.self,
        deepLink: { $0.path.isEmpty && $0.query.isEmpty ? .home : nil },
        resolver: { route, _ in
            switch route {
            case .home:
                UIHostingController(rootView: ScreenBView(store: Store(initialState: ScreenBFeature.State()) { ScreenBFeature() }))
            case .b2:
                UIHostingController(rootView: ScreenB2View(store: Store(initialState: ScreenB2Feature.State()) { ScreenB2Feature() }))
            }
        }
    )
}
