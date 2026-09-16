import AppRoutes
import ComposableArchitecture
import ScreenAFeature
import ScreenBFeature
import ScreenCKit
import ScreenDKit
import UIKit

/// The one place in the app that knows about every feature module. Turns an opaque `Destination`
/// into a concrete screen, whatever technology that screen happens to be built with.
@MainActor
enum ScreenResolver {
    static func viewController(for destination: Destination, navigator: Navigator) -> UIViewController {
        switch destination {
        case .screenA:
            ScreenAHostingController(store: Store(initialState: ScreenAFeature.State()) { ScreenAFeature() })
        case .screenB:
            ScreenBHostingController(store: Store(initialState: ScreenBFeature.State()) { ScreenBFeature() })
        case let .screenC(context):
            ScreenCViewController(navigator: navigator, context: context)
        case .screenD:
            ScreenDViewController(navigator: navigator)
        }
    }
}
