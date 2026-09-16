import AppRoutes
import ComposableArchitecture
import NavigatorDependency
import Observation
import SwiftNavigation
import UIKit
import UIKitNavigation

/// Builds the app's root view controller. This is the only entry point the app target
/// needs — everything about how navigation is wired lives behind it.
@MainActor
enum AppComposition {
    static func makeRootViewController() -> UIViewController {
        let navigator = AppNavigator()
        prepareDependencies { $0.navigator = navigator }

        let tabBarController = NavigatorTabBarController(navigator: navigator)
        tabBarController.viewControllers = [
            makeTab(root: .screenA, path: \.pathA, navigator: navigator, title: "Screen A", systemImage: "a.circle"),
            makeTab(root: .screenB, path: \.pathB, navigator: navigator, title: "Screen B", systemImage: "b.circle"),
            makeTab(root: .screenC, path: \.pathC, navigator: navigator, title: "Screen C", systemImage: "c.circle"),
            makeTab(root: .screenD, path: \.pathD, navigator: navigator, title: "Screen D", systemImage: "d.circle"),
        ]

        attachPresentation(on: tabBarController, host: navigator)

        return tabBarController
    }

    /// Recursively wires up `host`'s `presented` modal, and the modal presented on top of that
    /// one, and so on — however deep the chain of `Navigator.present(_:)` calls goes.
    private static func attachPresentation(on viewController: UIViewController, host: some PresentationHost & Observable) {
        viewController.present(item: UIBindable(host).presented) { presented in
            let stack = NavigationStackController(path: UIBindable(presented).path) {
                withDependencies { $0.navigator = presented } operation: {
                    ScreenResolver.viewController(for: presented.route, navigator: presented)
                }
            }
            stack.navigationDestination(for: Route.self) { route in
                withDependencies { $0.navigator = presented } operation: {
                    ScreenResolver.viewController(for: route, navigator: presented)
                }
            }
            attachPresentation(on: stack, host: presented)
            return stack
        }
    }

    private static func makeTab(
        root: Route,
        path: ReferenceWritableKeyPath<AppNavigator, [Route]>,
        navigator: AppNavigator,
        title: String,
        systemImage: String
    ) -> UIViewController {
        let pathBinding = UIBindable(navigator)[dynamicMember: path]
        let stack = NavigationStackController(path: pathBinding) {
            ScreenResolver.viewController(for: root, navigator: navigator)
        }
        stack.navigationDestination(for: Route.self) { route in
            ScreenResolver.viewController(for: route, navigator: navigator)
        }
        stack.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: systemImage), tag: 0)
        return stack
    }
}
