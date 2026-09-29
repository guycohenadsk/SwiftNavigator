import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct IssuesDetailView: View {
    @Bindable var store: StoreOf<IssuesDetail>
    @FocusState private var isTitleFocused: Bool

    public init(store: StoreOf<IssuesDetail>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Detail gets only the push line — present and the Screen C context demo stay on the
            // list, where Screen A had them.
            NavigationDemoStrip(onPush: { store.send(.navigateButtonTapped($0)) })

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleSection

                    ForEach(store.inlineFields, id: \.self) { field in
                        fieldView(field)
                        Divider()
                    }

                    if store.isGroupingEmptyFields {
                        EmptyFieldsSection(
                            count: store.emptyFields.count,
                            isExpanded: store.isEmptyFieldsExpanded,
                            onToggle: { store.send(.emptyFieldsToggled) }
                        ) {
                            ForEach(store.emptyFields, id: \.self) { field in
                                fieldView(field)
                                Divider()
                            }
                        }
                    }

                    CreatedByFooter(
                        name: store.issue.createdBy,
                        email: store.issue.createdByEmail,
                        date: store.issue.createdAt
                    )
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle(store.issue.number.map { "#\($0)" } ?? "New")
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                "Issue title",
                text: Binding(
                    get: { store.issue.title },
                    set: { store.send(.titleChanged($0)) }
                ),
                axis: .vertical
            )
            .font(.system(size: 22, weight: .semibold))
            .focused($isTitleFocused)
            .accessibilityIdentifier("issue_title_field")

            if isTitleFocused {
                Text("\(store.issue.title.count)/\(store.issue.maxTitleLength)")
                    .font(.caption)
                    .foregroundStyle(store.isTitleOverLimit ? Color.red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()

            if store.isTitleOverLimit {
                Text("Title cannot exceed \(store.issue.maxTitleLength) characters.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func fieldView(_ field: IssuesDetail.Field) -> some View {
        switch field {
        case .status:
            PickerFieldRow(
                label: field.label,
                value: store.issue.status,
                options: IssueStatus.allCases,
                title: \.title,
                allowsClearing: false,
                onSelect: { status in
                    if let status { store.send(.statusSelected(status)) }
                }
            )

        case .type:
            PickerFieldRow(
                label: field.label,
                value: store.issue.typeCode,
                options: Issue.typeCodeOptions,
                title: { $0 },
                onSelect: { store.send(.typeCodeSelected($0)) }
            )

        case .assignee:
            PickerFieldRow(
                label: field.label,
                value: store.issue.assigneeName,
                options: Issue.assigneeOptions,
                title: { $0 },
                onSelect: { store.send(.assigneeSelected($0)) }
            )

        case .location:
            PickerFieldRow(
                label: field.label,
                value: store.issue.location,
                options: Issue.locationOptions,
                title: { $0 },
                onSelect: { store.send(.locationSelected($0)) }
            )

        case .rootCause:
            PickerFieldRow(
                label: field.label,
                value: store.issue.rootCause,
                options: Issue.rootCauseOptions,
                title: { $0 },
                onSelect: { store.send(.rootCauseSelected($0)) }
            )

        case .issueDescription:
            ExpandableTextArea(
                label: field.label,
                text: store.issue.issueDescription,
                isExpanded: store.isDescriptionExpanded,
                onChange: { store.send(.descriptionChanged($0)) },
                onToggleExpanded: { store.send(.descriptionExpandToggled) }
            )

        case .locationDetails:
            ExpandableTextArea(
                label: field.label,
                text: store.issue.locationDetails ?? "",
                isExpanded: store.isLocationDetailsExpanded,
                onChange: { store.send(.locationDetailsChanged($0)) },
                onToggleExpanded: { store.send(.locationDetailsExpandToggled) }
            )

        case .dueDate, .startDate:
            DatePickerField(
                label: field.label,
                date: field == .dueDate ? store.issue.dueDate : store.issue.startDate,
                isExpanded: store.expandedDateField == field,
                onTap: { store.send(.dateFieldTapped(field)) },
                onChange: { store.send(field == .dueDate ? .dueDateChanged($0) : .startDateChanged($0)) }
            )
        }
    }
}
