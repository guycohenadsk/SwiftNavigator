import UIKit

/// Keeps `AppNavigator` aware of which tab's backstack a push/pop should apply to.
@MainActor
final class NavigatorTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let navigator: AppNavigator

    init(navigator: AppNavigator) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        navigator.tabIndex = tabBarController.selectedIndex
    }
}
