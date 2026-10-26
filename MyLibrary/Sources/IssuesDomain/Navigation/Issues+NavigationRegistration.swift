import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKit

extension Issues {
    public static let navigationRegistration = NavigationRegistration(
        target: IssuesNavigationContract.target,
        // A linked issue (`demoapp://issues/<id>`) opens from the tab's list, so the list applies
        // its edits and deletion like a tapped row's — not as a standalone detail.
        deepLinksToRoot: { request in
            if case .open = request.intent { true } else { false }
        },
        resolver: { request, _ in try viewController(for: route(for: request)) }
    )

    /// How other modules, and the navigator's stack, refer to `issue`.
    static func ref(for issue: Issue) -> EntityRef {
        EntityRef(target: .issues, id: issue.id.uuidString, title: issue.rowTitle)
    }

    /// The stack entry of `issue`'s detail as the list pushes it: one of Issues' inner screens, so
    /// the detail reports to the list instead of saving on its own.
    static func detailRequest(for issue: Issue) -> NavigationRequest {
        NavigationRequest(intent: .screen(.issues, name: listDetailsPrefix + issue.id.uuidString))
    }

    private static let listDetailsPrefix = "detail/"

    static func route(for request: NavigationRequest) throws -> IssuesNavigationContract.Route {
        guard request.target == IssuesNavigationContract.target else { throw NavigationError.wrongTarget }
        switch request.intent {
        case let .open(ref): return .details(id: ref.id)
        case .browse: return .list
        case .selectSingle: return .picker
        case let .screen(_, name) where name.hasPrefix(listDetailsPrefix):
            return .listDetails(id: String(name.dropFirst(listDetailsPrefix.count)))
        case .compose, .perform, .screen: throw NavigationError.unsupportedIntent
        }
    }

    @MainActor
    static func viewController(for route: IssuesNavigationContract.Route) -> UIViewController {
        switch route {
        case .list:
            return UIHostingController(rootView: IssuesListView(store: Store(initialState: IssuesList.State()) { IssuesList() }))
        case .picker:
            return UIHostingController(rootView: IssuesListView(store: Store(initialState: IssuesList.State(isPicker: true)) { IssuesList() }))
        case let .details(id):
            // Edits go straight to the stored issue; this screen deletes it itself.
            @Shared(.issues) var issues
            guard let uuid = UUID(uuidString: id), let issue = Shared($issues[id: uuid]) else { return issueNotFound() }
            return detailScreen(IssueDetailScreen.State(issue: issue, reportsToOpener: false))
        case let .listDetails(id):
            // A copy: the list applies the edits and the deletion this screen reports.
            @Shared(.issues) var issues
            guard let uuid = UUID(uuidString: id), let issue = issues[id: uuid] else { return issueNotFound() }
            return detailScreen(IssueDetailScreen.State(issue: Shared(value: issue), reportsToOpener: true))
        }
    }

    @MainActor
    private static func detailScreen(_ state: IssueDetailScreen.State) -> UIViewController {
        let store = Store(initialState: state) { IssueDetailScreen() }
        return UIHostingController(rootView: IssuesDetailView(store: store.scope(state: \.detail, action: \.detail)))
    }

    @MainActor
    private static func issueNotFound() -> UIViewController {
        UIHostingController(rootView: ContentUnavailableView("Issue not found", systemImage: "exclamationmark.triangle"))
    }
}
