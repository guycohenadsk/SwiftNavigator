import ComposableArchitecture
import SwiftUI

public struct RefPickerView: View {
    @Bindable var store: StoreOf<RefPicker>

    public init(store: StoreOf<RefPicker>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.references) { item in
                Button {
                    store.send(.referenceTapped(item))
                } label: {
                    HStack {
                        Text(item.title)
                            .font(.system(size: 15))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }

            Button {
                store.send(.addReferenceTapped)
            } label: {
                Label("Add Reference", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.vertical, 12)
            }
            .confirmationDialog($store.scope(state: \.chooser, action: \.chooser))
        }
    }
}
