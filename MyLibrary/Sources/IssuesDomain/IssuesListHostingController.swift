import ComposableArchitecture
import SwiftUI
import UIKitNavigation

/// Hosts `IssuesListView` and owns the in-module push to Issues Detail. Pushing via `UIKitNavigation`'s
/// `UIViewController.navigationDestination(item:)` puts the pushed screen directly onto this
/// controller's own `navigationController` — the same shared, per-tab stack the app already uses —
/// so there's only ever one navigation bar, no nested `NavigationStack` required.
public final class IssuesListHostingController: UIHostingController<IssuesListView> {
    @UIBindable var store: StoreOf<IssuesList>

    public init(store: StoreOf<IssuesList>) {
        self.store = store
        super.init(rootView: IssuesListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationDestination(item: $store.scope(\.detail, action: \.detail)) { store in
            UIHostingController(rootView: IssuesDetailView(store: store))
        }
    }
}
