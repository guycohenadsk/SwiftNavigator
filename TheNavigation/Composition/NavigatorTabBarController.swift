import UIKit
import UIKitNavigation

/// Keeps the selected tab and `AppNavigator.tabIndex` in sync, both ways: the user tapping a tab
/// updates the navigator, and the navigator switching tabs (a deep link) updates the tab bar.
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

    override func viewDidLoad() {
        super.viewDidLoad()
        observe { [weak self] in
            guard let self, selectedIndex != navigator.tabIndex else { return }
            selectedIndex = navigator.tabIndex
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        navigator.tabIndex = tabBarController.selectedIndex
    }
}
