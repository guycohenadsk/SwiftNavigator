import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKit

extension Issues {
    public static let navigationRegistration = NavigationRegistration(
        target: IssuesNavigationContract.target,
        // A linked issue (`demoapp://issues/<id>`) opens from the tab's list, as the list's own
        // child — not as a standalone detail.
        deepLinksToRoot: { request in
            if case .open = request.intent { true } else { false }
        },
        resolver: { request, context in try viewController(for: request, context: context) }
    )

    /// How other modules, and the navigator's stack, refer to `issue`.
    static func ref(for issue: Issue) -> EntityRef {
        EntityRef(target: .issues, id: issue.id.uuidString, title: issue.rowTitle)
    }

    /// The stack entry of `issue`'s detail as the list pushes it — one of Issues' inner screens,
    /// built from the list's store (`viewController(for:context:)`).
    static func detailRequest(for issue: Issue) -> NavigationRequest {
        NavigationRequest(intent: .screen(.issues, name: listDetailsPrefix + issue.id.uuidString))
    }

    /// A random stored issue's detail, opened standalone: `.screen(.issues, name: "random")`.
    static let randomIssueRequest = NavigationRequest(intent: .screen(.issues, name: randomIssueName))

    private static let listDetailsPrefix = "detail/"
    private static let randomIssueName = "random"

    static func route(for request: NavigationRequest) throws -> IssuesNavigationContract.Route {
        guard request.target == IssuesNavigationContract.target else { throw NavigationError.wrongTarget }
        switch request.intent {
        case let .open(ref): return .details(id: ref.id)
        case .browse: return .list
        case .selectSingle: return .picker
        case .screen(_, randomIssueName): return .randomDetails
        case let .screen(_, name) where name.hasPrefix(listDetailsPrefix):
            return .listDetails(id: String(name.dropFirst(listDetailsPrefix.count)))
        case .compose, .perform, .screen: throw NavigationError.unsupportedIntent
        }
    }

    @MainActor
    static func viewController(for request: NavigationRequest, context: NavigationContext) throws -> UIViewController {
        switch try route(for: request) {
        case .list:
            return IssuesListHostingController(store: Store(initialState: IssuesList.State()) { IssuesList() })
        case .picker:
            return IssuesListHostingController(store: Store(initialState: IssuesList.State(isPicker: true)) { IssuesList() })
        case let .details(id):
            // Opened by another module (Screen B, C, D, RefPicker): a detail that saves to the
            // stored issue and deletes it itself.
            return standaloneDetail(id: id)
        case .randomDetails:
            @Shared(.issues) var issues
            @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
            let stored = issues
            let issue = withRandomNumberGenerator { stored.randomElement(using: &$0) }
            return standaloneDetail(id: issue?.id.uuidString ?? "")
        case .listDetails:
            // The list that pushed it owns the detail's state: build the detail from the list's store,
            // scoped to `detail`; leaving sends `.detail(.dismiss)`.
            guard let list = context.parent as? IssuesListHostingController,
                  let detail = context.child(
                      for: request,
                      of: list.store,
                      state: \.detail,
                      action: \.detail,
                      requestOf: { detailRequest(for: $0.issue) },
                      content: { UIHostingController(rootView: IssuesDetailView(store: $0)) }
                  )
            else {
                reportIssue("Pushed \(request) from outside the Issues list, or without IssuesList.State.detail showing it.")
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
