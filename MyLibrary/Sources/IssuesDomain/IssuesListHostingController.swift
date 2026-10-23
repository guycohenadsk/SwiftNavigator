import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKitNavigation

/// Hosts `IssuesListView` and shows Issues Detail when the list's `detail` state is set. The push
/// goes through the app's `Navigator` (`navigatorDestination`), so the detail is an entry on the
/// tab's stack like any other screen — deep-link resets and `popToRoot` see it — while its state
/// stays in `IssuesList.State.detail`, so the detail still talks to the list through `.ifLet`.
public final class IssuesListHostingController: UIHostingController<IssuesListView> {
    @UIBindable var store: StoreOf<IssuesList>
    @Dependency(\.navigator) private var navigator

    public init(store: StoreOf<IssuesList>) {
        self.store = store
        super.init(rootView: IssuesListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigatorDestination(
            item: $store.scope(\.detail, action: \.detail),
            navigator: navigator,
            id: { $0.issue.id },
            request: { NavigationRequest(intent: .open(Issues.ref(for: $0.issue))) }
        ) { store in
            UIHostingController(rootView: IssuesDetailView(store: store))
        }
    }
}
