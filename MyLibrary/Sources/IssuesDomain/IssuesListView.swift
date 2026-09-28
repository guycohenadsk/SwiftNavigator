import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct IssuesListView: View {
    let store: StoreOf<IssuesList>

    public init(store: StoreOf<IssuesList>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavigationDemoStrip(
                pushRoutes: Route.allCases.filter { $0 != .issues },
                onPush: { store.send(.navigateButtonTapped($0)) },
                onPresent: { store.send(.presentButtonTapped($0)) },
                onPushScreenCWithContext: { store.send(.pushScreenCWithContextTapped) },
                screenCText: store.screenCText
            )

            Divider()

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
        }
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addIssueTapped)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("add_issue_button")
            }
        }
    }
}
