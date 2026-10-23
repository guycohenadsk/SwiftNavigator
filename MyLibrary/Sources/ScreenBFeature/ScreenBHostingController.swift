import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import ScreenBNavigationContract
import SwiftUI
import UIKitNavigation

/// Hosts `ScreenBView` and shows Screen B2 when `ScreenBFeature.State.screenB2` is set. The push goes
/// through the app's `Navigator` (`navigatorDestination`) as Screen B's `.b2` entry, while B2's state
/// stays in Screen B, so B2 still talks to Screen B through `.ifLet`.
public final class ScreenBHostingController: UIHostingController<ScreenBView> {
    @UIBindable var store: StoreOf<ScreenBFeature>
    @Dependency(\.navigator) private var navigator

    public init(store: StoreOf<ScreenBFeature>) {
        self.store = store
        super.init(rootView: ScreenBView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigatorDestination(
            item: $store.scope(\.screenB2, action: \.screenB2),
            navigator: navigator,
            id: { _ in ScreenBNavigationContract.Screen.b2 },
            request: { _ in ScreenBNavigationContract.request(for: .b2) }
        ) { store in
            UIHostingController(rootView: ScreenB2View(store: store))
        }
    }
}
