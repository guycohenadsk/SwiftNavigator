import ComposableArchitecture
import SwiftUI

public struct IssuesScopeListView: View {
    let store: StoreOf<IssuesScopeList>

    public init(store: StoreOf<IssuesScopeList>) {
        self.store = store
    }

    public var body: some View {
        List {
            ForEach(Array(store.issues.enumerated()), id: \.element.id) { index, issue in
                Button {
                    store.send(.issueTapped(issue.id))
                } label: {
                    IssueRowView(issue: issue, index: index)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .onDelete { store.send(.deleteIssues($0)) }
        }
        .listStyle(.plain)
        .onAppear { store.send(.onAppear) }
        .navigationTitle("Issues (scope)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addIssueTapped)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("add_scope_issue_button")
            }
        }
    }
}
