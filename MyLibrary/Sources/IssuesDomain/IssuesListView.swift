import AppRoutes
import ComposableArchitecture
import SwiftUI

public struct IssuesListView: View {
    let store: StoreOf<IssuesList>
    @State private var isShowingInfo = false

    public init(store: StoreOf<IssuesList>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Issues") {
                Text("SwiftUI, driven by a TCA reducer.")
                    .foregroundStyle(.secondary)
            }
            Section("Within this module") {
                Button("Push to Issues Detail") {
                    store.send(.pushDetailTapped)
                }
            }
            Section("Cross-module delegate") {
                Button("Push Screen C with context") {
                    store.send(.pushScreenCWithContextTapped)
                }
                if let text = store.screenCText {
                    LabeledContent("Screen C sent", value: text)
                }
            }
            Section("Navigate to") {
                ForEach(Route.allCases.filter { $0 != .issues }, id: \.self) { route in
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
        .navigationTitle("Issues")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .alert("Issues", isPresented: $isShowingInfo) {
        } message: {
            Text("SwiftUI, driven by a TCA reducer.")
        }
    }
}
