    import ComposableArchitecture
import SwiftUI

public struct IssuesListView: View {
    let store: StoreOf<IssuesList>

    public init(store: StoreOf<IssuesList>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !store.isPicker {
                NavigationDemoStrip(lines: [
                    .init(label: "Push", links: [
                        .init("Screen B") { store.send(.pushTapped(.screenB)) },
                        .init("Screen C") { store.send(.pushTapped(.screenC)) },
                        .init("Screen D") { store.send(.pushTapped(.screenD)) },
                    ]),
                    .init(label: "Present", links: [
                        .init("Issues") { store.send(.presentTapped(.issues)) },
                        .init("Screen B") { store.send(.presentTapped(.screenB)) },
                        .init("Screen C") { store.send(.presentTapped(.screenC)) },
                        .init("Screen D") { store.send(.presentTapped(.screenD)) },
                    ]),
                    .init(label: "Context", links: [
                        .init(
                            store.screenCText.map { "Screen C said “\($0)”" } ?? "Push Screen C with context",
                            isHighlighted: store.screenCText != nil
                        ) { store.send(.pushScreenCWithContextTapped) },
                    ]),
                ])

                Divider()
            }

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
                .onDelete(perform: store.isPicker ? nil : { store.send(.deleteIssues($0)) })
            }
            .listStyle(.plain)
        }
        .onAppear { store.send(.onAppear) }
        .navigationTitle(store.isPicker ? "Pick an issue" : "Issues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !store.isPicker {
                    addButton
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            store.send(.addIssueTapped)
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityIdentifier("add_issue_button")
    }
}
