import ComposableArchitecture
import RefPicker
import SwiftUI

public struct RFIDetailView: View {
    @Bindable var store: StoreOf<RFIDetail>

    public init(store: StoreOf<RFIDetail>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(
                        "RFI subject",
                        text: Binding(
                            get: { store.rfi.subject },
                            set: { store.send(.subjectChanged($0)) }
                        ),
                        axis: .vertical
                    )
                    .font(.system(size: 22, weight: .semibold))
                    .accessibilityIdentifier("rfi_subject_field")

                    Divider()
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                PickerFieldRow(
                    label: "Status",
                    value: store.rfi.status,
                    options: RFIStatus.allCases,
                    title: \.displayName,
                    allowsClearing: false,
                    onSelect: { status in
                        if let status { store.send(.statusSelected(status)) }
                    }
                )
                Divider()

                PickerFieldRow(
                    label: "Assigned to",
                    value: store.rfi.assigneeName,
                    options: RFIItem.assigneeOptions,
                    title: { $0 },
                    onSelect: { store.send(.assigneeSelected($0)) }
                )
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Question")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(
                        "Describe the question",
                        text: Binding(
                            get: { store.rfi.question },
                            set: { store.send(.questionChanged($0)) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...)
                }
                .padding(.vertical, 12)
                Divider()

                DatePickerField(
                    label: "Due date",
                    date: store.rfi.dueDate,
                    isExpanded: store.isDueDateExpanded,
                    onTap: { store.send(.dueDateTapped) },
                    onChange: { store.send(.dueDateChanged($0)) }
                )
                Divider()

                Text("Related")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                RefPickerView(store: store.scope(state: \.references, action: \.references))
                Divider()

                CreatedByFooter(
                    name: store.rfi.createdBy,
                    email: store.rfi.createdByEmail,
                    date: store.rfi.createdAt
                )
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(store.rfi.number.map { String(format: "RFI-%03d", $0) } ?? "New")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.send(.deleteButtonTapped)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("more_actions_button")
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
