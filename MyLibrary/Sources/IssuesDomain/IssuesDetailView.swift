import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct IssuesDetailView: View {
    let store: StoreOf<IssuesDetail>

    public init(store: StoreOf<IssuesDetail>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavigationDemoStrip(onPush: { store.send(.navigateButtonTapped($0)) })
            Divider()
            List {
                LabeledContent("Title", value: store.issue.title)
                LabeledContent("Status", value: store.issue.status.title)
            }
        }
        .navigationTitle(store.issue.number.map { "#\($0)" } ?? "New")
        .navigationBarTitleDisplayMode(.inline)
    }
}
