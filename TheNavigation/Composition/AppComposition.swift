import ComposableArchitecture
import IssuesDomain
import NavigationCore
import NavigatorDependency
import ScreenBFeature
import ScreenCKit
import ScreenDKit
import SwiftUI
import UIKit
import UIKitNavigation

/// A tab: the request its root screen comes from, and how it looks in the tab bar.
struct TabSpec {
    let root: NavigationRequest
    let title: String
    let systemImage: String
}

/// The composition root — the only place that imports every feature. It lists the modules taking
/// part in navigation and the tabs; it knows nothing about individual screens.
@MainActor
enum AppComposition {
    static let registrations = [
        Issues.navigationRegistration,
        ScreenB.navigationRegistration,
        ScreenC.navigationRegistration,
        ScreenD.navigationRegistration,
    ]

    static let tabs = [
        TabSpec(root: NavigationRequest(intent: .browse(.issues)), title: "Issues", systemImage: "exclamationmark.bubble"),
        TabSpec(root: NavigationRequest(intent: .browse(.screenB)), title: "Screen B", systemImage: "b.circle"),
        TabSpec(root: NavigationRequest(intent: .browse(.screenC)), title: "Screen C", systemImage: "c.circle"),
        TabSpec(root: NavigationRequest(intent: .browse(.screenD)), title: "Screen D", systemImage: "d.circle"),
    ]

    static func makeRegistry() throws -> NavigationRegistry {
        let registry = NavigationRegistry()
        try registrations.forEach { try registry.register($0) }
        return registry
    }

    static func makeRootViewController(navigator: AppNavigator) -> UIViewController {
        let registry: NavigationRegistry
        do {
            registry = try makeRegistry()
        } catch {
            assertionFailure("Navigation registry setup failed: \(error)")
            registry = NavigationRegistry()
        }
        prepareDependencies { $0.navigator = navigator }
        navigator.deepLinksToRoot = { request in
            if case .perform = request.intent { return true }
            return registry.deepLinksToRoot(request)
        }

        let resolve: (NavigationRequest, NavigationContext) -> UIViewController = { request, context in
            do {
                return try registry.resolve(request, context: context)
            } catch {
                assertionFailure("Failed to resolve \(request): \(error)")
                return UIHostingController(rootView: ContentUnavailableView("Can't open \(request.target.rawValue)", systemImage: "exclamationmark.triangle"))
            }
        }

        let tabBarController = NavigatorTabBarController(navigator: navigator)
        tabBarController.viewControllers = tabs.indices.map { index in
            let stack = makeStack(navigator.tabs[index], root: tabs[index].root, navigator: navigator, resolve: resolve)
            stack.tabBarItem = UITabBarItem(title: tabs[index].title, image: UIImage(systemName: tabs[index].systemImage), tag: index)
            return stack
        }
        attachModal(at: 0, on: tabBarController, navigator: navigator, resolve: resolve)
        return tabBarController
    }

    /// A UIKit navigation stack bound to `stack.path`, with `root` at the bottom.
    private static func makeStack(
        _ stack: StackNavigator,
        root: NavigationRequest,
        navigator: AppNavigator,
        resolve: @escaping (NavigationRequest, NavigationContext) -> UIViewController
    ) -> UIViewController {
        let controller = NavigationStackController(path: UIBindable(stack).path) {
            resolve(root, NavigationContext(navigator: navigator))
        }
        // Each entry is resolved with the screen it was pushed from (the stack's top), so a module can
        // build a child from its parent, and with a hook for when the entry leaves.
        controller.navigationDestination(for: NavigationEntry.self) { [weak controller, weak stack] entry in
            resolve(entry.request, NavigationContext(
                navigator: navigator,
                parent: controller?.topViewController,
                onLeave: { stack?.onLeave(entry.id, $0) }
            ))
        }
        stack.controller = controller
        return controller
    }

    /// Presents modal `level` on `presenter` whenever it exists, then wires `level + 1` on top of it —
    /// however many modals deep the app goes.
    private static func attachModal(
        at level: Int,
        on presenter: UIViewController,
        navigator: AppNavigator,
        resolve: @escaping (NavigationRequest, NavigationContext) -> UIViewController
    ) {
        presenter.present(item: UIBindable(navigator)[dynamicMember: \AppNavigator.[modalAt: level]]) { modal in
            let stack = makeStack(modal.stack, root: modal.root.request, navigator: navigator, resolve: resolve)
            attachModal(at: level + 1, on: stack, navigator: navigator, resolve: resolve)
            return stack
        }
    }
}
