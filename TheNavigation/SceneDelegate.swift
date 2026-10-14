import NavigationCore
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let navigator = AppNavigator(tabRoots: AppComposition.tabs.map(\.root))

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = AppComposition.makeRootViewController(navigator: navigator)
        window.makeKeyAndVisible()
        self.window = window
        handle(connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(URLContexts)
    }

    /// Same pipeline as an in-app tap. Invalid links are ignored.
    private func handle(_ contexts: Set<UIOpenURLContext>) {
        guard let url = contexts.first?.url, let request = try? DeepLinkParser.parse(url) else { return }
        navigator.open(deepLink: request)
    }
}
