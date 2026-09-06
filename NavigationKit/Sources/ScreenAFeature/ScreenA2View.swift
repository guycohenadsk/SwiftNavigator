import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct ScreenA2View: View {
    let store: StoreOf<ScreenA2Feature>

    public init(store: StoreOf<ScreenA2Feature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Screen A2") {
                Text("Pushed locally from Screen A, within the same module.")
                    .foregroundStyle(.secondary)
            }
            Section("Navigate to") {
                ForEach(Route.allCases.filter { $0 != .screenA }, id: \.self) { route in
                    Button(route.title) {
                        store.send(.navigateButtonTapped(route))
                    }
                }
            }
        }
        .navigationTitle("Screen A2")
    }
}
