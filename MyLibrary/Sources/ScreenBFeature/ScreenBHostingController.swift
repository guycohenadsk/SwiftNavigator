import ComposableArchitecture
import SwiftUI
import UIKitNavigation

/// Hosts `ScreenBView` and owns the in-module push to Screen B2. Pushing via `UIKitNavigation`'s
/// `UIViewController.navigationDestination(item:)` puts the pushed screen directly onto this
/// controller's own `navigationController` — the same shared, per-tab stack the app already uses —
/// so there's only ever one navigation bar, no nested `NavigationStack` required.
public final class ScreenBHostingController: UIHostingController<ScreenBView> {
    @UIBindable var store: StoreOf<ScreenBFeature>

    public init(store: StoreOf<ScreenBFeature>) {
        self.store = store
        super.init(rootView: ScreenBView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationDestination(item: $store.scope(\.screenB2, action: \.screenB2)) { store in
            UIHostingController(rootView: ScreenB2View(store: store))
        }
    }
}
