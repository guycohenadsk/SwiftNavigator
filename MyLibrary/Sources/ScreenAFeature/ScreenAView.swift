import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct ScreenAView: View {
    let store: StoreOf<ScreenAFeature>
    @State private var isShowingInfo = false

    public init(store: StoreOf<ScreenAFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Screen A") {
                Text("SwiftUI, driven by a TCA reducer.")
                    .foregroundStyle(.secondary)
            }
            Section("Within this module") {
                Button("Push to Screen A2") {
                    store.send(.pushScreenA2Tapped)
                }
            }
            Section("Navigate to") {
                ForEach(Route.allCases.filter { $0 != .screenA }, id: \.self) { route in
                    Button(route.title) {
                        store.send(.navigateButtonTapped(route))
                    }
                }
            }
            Section("Show modally") {
                ForEach(Route.allCases, id: \.self) { route in
                    Button(route.title) {
                        store.send(.presentButtonTapped(route))
                    }
                }
            }
        }
        .navigationTitle("Screen A")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .alert("Screen A", isPresented: $isShowingInfo) {
        } message: {
            Text("SwiftUI, driven by a TCA reducer.")
        }
    }
}
