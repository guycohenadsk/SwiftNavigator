import ComposableArchitecture
import SwiftUI

public struct RFIListView: View {
    let store: StoreOf<RFIList>

    public init(store: StoreOf<RFIList>) {
        self.store = store
    }

    public var body: some View {
        List {
            ForEach(Array(store.rfis.enumerated()), id: \.element.id) { index, rfi in
                Button {
                    store.send(.rfiTapped(rfi.id))
                } label: {
                    RFIRowView(rfi: rfi, index: index)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: store.isPicker ? nil : { store.send(.deleteRFIs($0)) })
        }
        .listStyle(.plain)
        .navigationTitle(store.isPicker ? "Pick an RFI" : "RFIs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !store.isPicker {
                    Button {
                        store.send(.addRFITapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add_rfi_button")
                }
            }
        }
    }
}
