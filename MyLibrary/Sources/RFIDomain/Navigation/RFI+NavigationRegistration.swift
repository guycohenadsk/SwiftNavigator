import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import RFINavigationContract
import SwiftUI
import UIKit

extension RFI {
    public static let navigationRegistration = NavigationRegistration(
        RFINavigationContract.Route.self,
        deepLink: { link in
            switch (link.path.first, link.query["action"]) {
            case (nil, nil): .list
            case let (id?, nil): .open(id: id)
            default: nil
            }
        },
        // Nothing is handed to a root screen: a linked RFI is pushed as the standalone detail.
        toRoot: { _ in false },
        resolver: { route, context in viewController(for: route, context: context) }
    )

    /// How other modules, and the navigator's stack, refer to `rfi`.
    static func ref(for rfi: RFIItem) -> EntityRef {
        EntityRef(
            id: rfi.id.uuidString,
            title: rfi.rowTitle,
            open: NavigationRequest(RFINavigationContract.Route.open(id: rfi.id.uuidString))
        )
    }

    @MainActor
    static func viewController(for route: RFINavigationContract.Route, context: NavigationContext) -> UIViewController {
        switch route {
        case .list:
            return RFIListHostingController(store: Store(initialState: RFIList.State()) { RFIList() })
        case .pick:
            return RFIListHostingController(store: Store(initialState: RFIList.State(isPicker: true)) { RFIList() })
        case let .open(id):
            return standaloneDetail(id: id)
        }
    }

    @MainActor
    private static func standaloneDetail(id: String) -> UIViewController {
        @Shared(.rfis) var rfis
        guard let uuid = UUID(uuidString: id), let rfi = Shared($rfis[id: uuid]) else { return rfiNotFound() }
        let store = Store(initialState: RFIDetailScreen.State(rfi: rfi)) { RFIDetailScreen() }
        return UIHostingController(rootView: RFIDetailView(store: store.scope(state: \.detail, action: \.detail)))
    }

    @MainActor
    private static func rfiNotFound() -> UIViewController {
        UIHostingController(rootView: ContentUnavailableView("RFI not found", systemImage: "exclamationmark.triangle"))
    }
}
