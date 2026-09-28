import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct IssuesDetailView: View {
    let store: StoreOf<IssuesDetail>

    public init(store: StoreOf<IssuesDetail>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Issues Detail") {
                Text("Pushed locally from Issues, within the same module.")
                    .foregroundStyle(.secondary)
            }
            Section("Navigate to") {
                ForEach(Route.allCases.filter { $0 != .issues }, id: \.self) { route in
                    Button(route.title) {
                        store.send(.navigateButtonTapped(route))
                    }
                }
            }
        }
        .navigationTitle("Issues Detail")
    }
}
