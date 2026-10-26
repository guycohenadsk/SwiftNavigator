import ComposableArchitecture
import SwiftUI

/// Hosts `IssuesListView`, and holds the list's store so the Issues registration can build the
/// list's detail from it (`Issues.viewController(for:context:)`).
public final class IssuesListHostingController: UIHostingController<IssuesListView> {
    let store: StoreOf<IssuesList>

    public init(store: StoreOf<IssuesList>) {
        self.store = store
        super.init(rootView: IssuesListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }
}
