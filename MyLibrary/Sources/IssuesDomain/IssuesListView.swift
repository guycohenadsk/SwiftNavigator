import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import ScreenBNavigationContract
import ScreenCNavigationContract
import ScreenDNavigationContract
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
                        .init("Screen B") { store.send(.pushTapped(NavigationRequest(ScreenBNavigationContract.Route.home))) },
                        .init("Screen C") { store.send(.pushTapped(NavigationRequest(ScreenCNavigationContract.Route.home))) },
                        .init("Screen D") { store.send(.pushTapped(NavigationRequest(ScreenDNavigationContract.Route.home))) },
                        .init("Random issue") { store.send(.randomIssueTapped) },
                    ]),
                    .init(label: "Present", links: [
                        .init("Issues") { store.send(.presentTapped(NavigationRequest(IssuesNavigationContract.Route.list))) },
                        .init("Screen B") { store.send(.presentTapped(NavigationRequest(ScreenBNavigationContract.Route.home))) },
                        .init("Screen C") { store.send(.presentTapped(NavigationRequest(ScreenCNavigationContract.Route.home))) },
                        .init("Screen D") { store.send(.presentTapped(NavigationRequest(ScreenDNavigationContract.Route.home))) },
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
