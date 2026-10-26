import ComposableArchitecture
import SwiftUI

/// Hosts `IssuesScopeListView`, and holds the list's store so the scope registration can build the
/// list's detail from it (`Issues.scopeViewController(for:context:)`).
public final class IssuesScopeListHostingController: UIHostingController<IssuesScopeListView> {
    let store: StoreOf<IssuesScopeList>

    public init(store: StoreOf<IssuesScopeList>) {
        self.store = store
        super.init(rootView: IssuesScopeListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }
}
