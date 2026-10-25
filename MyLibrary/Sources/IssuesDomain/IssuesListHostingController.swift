import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKitNavigation

/// Hosts `IssuesListView` and says how to build Issues Detail from the list's `detail` state. The
/// list's reducer sets that state and pushes it through its `ChildNavigator`; the push goes through
/// the app's `Navigator`, so the detail is an entry on the tab's stack like any other screen, while
/// its state stays in `IssuesList.State.detail` and it talks to the list through `.ifLet`.
public final class IssuesListHostingController: UIHostingController<IssuesListView> {
    @UIBindable var store: StoreOf<IssuesList>
    let childNavigator: ChildNavigator
    @Dependency(\.navigator) private var navigator

    /// Builds the list's store with its own `ChildNavigator`, bound to this controller.
    public convenience init(initialState: IssuesList.State) {
        let children = ChildNavigator()
        let store = Store(initialState: initialState) { IssuesList() } withDependencies: {
            $0.childNavigator = children
        }
        self.init(store: store, children: children)
    }

    /// `children` must be the `ChildNavigator` `store` was built with.
    public init(store: StoreOf<IssuesList>, children: ChildNavigator) {
        self.store = store
        self.childNavigator = children
        super.init(rootView: IssuesListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        childDestination(
            item: $store.scope(\.detail, action: \.detail),
            children: childNavigator,
            navigator: navigator,
            id: { $0.issue.id },
            request: { Issues.detailRequest(for: $0.issue) }
        ) { store in
            UIHostingController(rootView: IssuesDetailView(store: store))
        }
    }
}
