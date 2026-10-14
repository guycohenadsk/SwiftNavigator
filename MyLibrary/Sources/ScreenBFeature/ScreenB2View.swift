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
                Button("Issues") { store.send(.openIssuesTapped) }
                Button("Screen D · sheet") { store.send(.openScreenDAsSheetTapped) }
            }
        }
        .navigationTitle("Screen B2")
    }
}
