import ComposableArchitecture
import SwiftUI
import UIKitNavigation

/// Hosts `ScreenAView` and owns the in-module push to Screen A2. Pushing via `UIKitNavigation`'s
/// `UIViewController.navigationDestination(item:)` puts the pushed screen directly onto this
/// controller's own `navigationController` — the same shared, per-tab stack the app already uses —
/// so there's only ever one navigation bar, no nested `NavigationStack` required.
public final class ScreenAHostingController: UIHostingController<ScreenAView> {
    @UIBindable var store: StoreOf<ScreenAFeature>

    public init(store: StoreOf<ScreenAFeature>) {
        self.store = store
        super.init(rootView: ScreenAView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationDestination(item: $store.scope(\.screenA2, action: \.screenA2)) { store in
            UIHostingController(rootView: ScreenA2View(store: store))
        }
    }
}
