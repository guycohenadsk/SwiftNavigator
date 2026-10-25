import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract
import SwiftUI
import UIKitNavigation

/// Hosts `ScreenBView` and says how to build Screen B2 from `ScreenBFeature.State.screenB2`. Screen
/// B's reducer sets that state and pushes it through its `ChildNavigator`, as Screen B's `.b2` entry;
/// B2's state stays in Screen B, so B2 still talks to Screen B through `.ifLet`.
public final class ScreenBHostingController: UIHostingController<ScreenBView> {
    @UIBindable var store: StoreOf<ScreenBFeature>
    let childNavigator: ChildNavigator
    @Dependency(\.navigator) private var navigator

    /// Builds Screen B's store with its own `ChildNavigator`, bound to this controller.
    public convenience init(initialState: ScreenBFeature.State) {
        let children = ChildNavigator()
        let store = Store(initialState: initialState) { ScreenBFeature() } withDependencies: {
            $0.childNavigator = children
        }
        self.init(store: store, children: children)
    }

    /// `children` must be the `ChildNavigator` `store` was built with.
    public init(store: StoreOf<ScreenBFeature>, children: ChildNavigator) {
        self.store = store
        self.childNavigator = children
        super.init(rootView: ScreenBView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        childDestination(
            item: $store.scope(\.screenB2, action: \.screenB2),
            children: childNavigator,
            navigator: navigator,
            id: { _ in ScreenBNavigationContract.Screen.b2 },
            request: { _ in ScreenBNavigationContract.request(for: .b2) }
        ) { store in
            UIHostingController(rootView: ScreenB2View(store: store))
        }
    }
}
