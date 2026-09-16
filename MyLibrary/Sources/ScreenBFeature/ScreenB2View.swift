import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct ScreenB2View: View {
    let store: StoreOf<ScreenB2Feature>

    public init(store: StoreOf<ScreenB2Feature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Screen B2") {
                Text("Pushed locally from Screen B, within the same module.")
                    .foregroundStyle(.secondary)
            }
            Section("Navigate to") {
                ForEach(Route.allCases.filter { $0 != .screenB }, id: \.self) { route in
                    Button(route.title) {
                        store.send(.navigateButtonTapped(route))
                    }
                }
            }
        }
        .navigationTitle("Screen B2")
    }
}
