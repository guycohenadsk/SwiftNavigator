import ComposableArchitecture
import SwiftUI

/// Hosts `RFIListView`, and holds the list's store.
public final class RFIListHostingController: UIHostingController<RFIListView> {
    let store: StoreOf<RFIList>

    public init(store: StoreOf<RFIList>) {
        self.store = store
        super.init(rootView: RFIListView(store: store))
    }

    @available(*, unavailable)
    @MainActor
    public required dynamic init?(coder aDecoder: NSCoder) { fatalError() }
}
