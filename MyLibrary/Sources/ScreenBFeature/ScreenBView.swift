import ComposableArchitecture
import SwiftUI

public struct ScreenBView: View {
    let store: StoreOf<ScreenBFeature>
    @State private var isShowingInfo = false

    public init(store: StoreOf<ScreenBFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Screen B") {
                Text("SwiftUI, driven by a TCA reducer.")
                    .foregroundStyle(.secondary)
            }
            Section("Within this module") {
                Button("Push to Screen B2") {
                    store.send(.pushScreenB2Tapped)
                }
            }
            Section("Cross-module result") {
                Button(store.linkedIssue == nil ? "Link an issue" : "Link another issue") {
                    store.send(.linkIssueTapped)
                }
                if let issue = store.linkedIssue {
                    Button {
                        store.send(.openLinkedIssueTapped)
                    } label: {
                        LabeledContent("Linked", value: issue.title)
                    }
                }
            }
            Section("Navigate to") {
                Button("Issues") { store.send(.openIssuesTapped) }
                Button("Screen D") { store.send(.openScreenDTapped) }
            }
        }
        .navigationTitle("Screen B")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .alert("Screen B", isPresented: $isShowingInfo) {
        } message: {
            Text("SwiftUI, driven by a TCA reducer.")
        }
    }
}
