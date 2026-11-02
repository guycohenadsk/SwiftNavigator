import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKit

extension Issues {
    public static let navigationRegistration = NavigationRegistration(
        IssuesNavigationContract.Route.self,
        deepLink: { link in
            switch (link.path.first, link.query["action"]) {
            case (nil, nil): .list
            case let (id?, nil): .open(id: id)
            case (_, .some(screenCContextAction)): .screenCContext
            default: nil
            }
        },
        // A linked issue (`demoapp://issues/<id>`) opens from the tab's list, as the list's own
        // child — not as a standalone detail. The Screen C action runs in that list too.
        toRoot: { route in
            switch route {
            case .open, .screenCContext: true
            case .list, .pick, .random, .listDetails: false
            }
        },
        resolver: { route, context in viewController(for: route, context: context) }
    )

    /// How other modules, and the navigator's stack, refer to `issue`.
    static func ref(for issue: Issue) -> EntityRef {
        EntityRef(
            id: issue.id.uuidString,
            title: issue.rowTitle,
            open: NavigationRequest(IssuesNavigationContract.Route.open(id: issue.id.uuidString))
        )
    }

    /// The stack entry of `issue`'s detail as the list pushes it — one of Issues' inner screens,
    /// built from the list's store (`viewController(for:context:)`).
    static func detailRequest(for issue: Issue) -> NavigationRequest {
        NavigationRequest(IssuesNavigationContract.Route.listDetails(id: issue.id.uuidString))
    }

    @MainActor
    static func viewController(for route: IssuesNavigationContract.Route, context: NavigationContext) -> UIViewController {
        switch route {
        case .list:
            return IssuesListHostingController(store: Store(initialState: IssuesList.State()) { IssuesList() })
        case .pick:
            return IssuesListHostingController(store: Store(initialState: IssuesList.State(isPicker: true)) { IssuesList() })
        case let .open(id):
            // Opened by another module (Screen B, C, D, RefPicker): a detail that saves to the
            // stored issue and deletes it itself.
            return standaloneDetail(id: id)
        case .random:
            @Shared(.issues) var issues
            @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
            let stored = issues
            let issue = withRandomNumberGenerator { stored.randomElement(using: &$0) }
            return standaloneDetail(id: issue?.id.uuidString ?? "")
        case .screenCContext:
            // Only the list at the tab's root acts on it, receiving it as `.incomingRequest`.
            reportIssue("Resolved \(route), which only a deep link to the Issues list can carry.")
            return UIHostingController(rootView: ContentUnavailableView("Nothing to show", systemImage: "exclamationmark.triangle"))
        case .listDetails:
            // The list that pushed it owns the detail's state: build the detail from the list's store,
            // scoped to `detail`; leaving sends `.detail(.dismiss)`.
            guard let list = context.parent as? IssuesListHostingController,
                  let detail = context.child(
                      for: NavigationRequest(route),
                      of: list.store,
                      state: \.detail,
                      action: \.detail,
                      requestOf: { detailRequest(for: $0.issue) },
                      content: { UIHostingController(rootView: IssuesDetailView(store: $0)) }
                  )
            else {
                reportIssue("Pushed \(route) from outside the Issues list, or without IssuesList.State.detail showing it.")
                return UIHostingController(rootView: ContentUnavailableView("Can't open this issue", systemImage: "exclamationmark.triangle"))
            }
            return detail
        }
    }

    @MainActor
    private static func standaloneDetail(id: String) -> UIViewController {
        @Shared(.issues) var issues
        guard let uuid = UUID(uuidString: id), let issue = Shared($issues[id: uuid]) else { return issueNotFound() }
        let store = Store(initialState: IssueDetailScreen.State(issue: issue)) { IssueDetailScreen() }
        return UIHostingController(rootView: IssuesDetailView(store: store.scope(state: \.detail, action: \.detail)))
    }

    @MainActor
    private static func issueNotFound() -> UIViewController {
        UIHostingController(rootView: ContentUnavailableView("Issue not found", systemImage: "exclamationmark.triangle"))
    }
}
