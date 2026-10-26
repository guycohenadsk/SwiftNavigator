import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKit

extension Issues {
    /// The second Issues tab, `IssuesScopeList`, whose list keeps its detail's state.
    public static let scopeNavigationRegistration = NavigationRegistration(
        target: .issuesScope,
        // A linked issue (`demoapp://issues-scope/<id>`) opens as the tab list's own child.
        deepLinksToRoot: { request in
            if case .open = request.intent { true } else { false }
        },
        resolver: { request, context in try scopeViewController(for: request, context: context) }
    )

    /// The stack entry of `issue`'s detail as the scope list pushes it — one of its inner screens,
    /// built from the list's store (`scopeViewController(for:context:)`).
    static func scopeDetailRequest(for issue: Issue) -> NavigationRequest {
        NavigationRequest(intent: .screen(.issuesScope, name: scopeDetailPrefix + issue.id.uuidString))
    }

    /// The issue a scope-list detail request is for, or `nil` for any other request.
    static func scopeDetailID(in request: NavigationRequest) -> Issue.ID? {
        guard case let .screen(.issuesScope, name) = request.intent, name.hasPrefix(scopeDetailPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(scopeDetailPrefix.count)))
    }

    private static let scopeDetailPrefix = "detail/"

    @MainActor
    static func scopeViewController(for request: NavigationRequest, context: NavigationContext) throws -> UIViewController {
        guard request.target == .issuesScope else { throw NavigationError.wrongTarget }
        switch request.intent {
        case .browse:
            return IssuesScopeListHostingController(store: Store(initialState: IssuesScopeList.State()) { IssuesScopeList() })
        case let .open(ref):
            // Not from the list (deep links go to it): a detail that saves and deletes on its own.
            return viewController(for: .details(id: ref.id))
        case .screen where scopeDetailID(in: request) != nil:
            // The list that pushed it owns the detail's state: build the detail from the list's store,
            // scoped to `detail`; leaving sends `.detail(.dismiss)`.
            guard let list = context.parent as? IssuesScopeListHostingController,
                  let detail = context.child(
                      for: request,
                      of: list.store,
                      state: \.detail,
                      action: \.detail,
                      requestOf: { scopeDetailRequest(for: $0.issue) },
                      content: { UIHostingController(rootView: IssuesDetailView(store: $0)) }
                  )
            else {
                reportIssue("Pushed \(request) from outside the scope list, or without IssuesScopeList.State.detail showing it.")
                return UIHostingController(rootView: ContentUnavailableView("Can't open this issue", systemImage: "exclamationmark.triangle"))
            }
            return detail
        case .selectSingle, .compose, .perform, .screen:
            throw NavigationError.unsupportedIntent
        }
    }
}
