import ComposableArchitecture
import IssuesNavigationContract
import NavigationCore
import NavigatorDependency
import SwiftUI
import UIKit

extension Issues {
    public static let navigationRegistration = NavigationRegistration(
        target: IssuesNavigationContract.target,
        // A linked issue (`demoapp://issues/<id>`) opens as a child of the tab's list, so the list
        // owns its state like a tapped row's — not as a standalone detail.
        deepLinksToRoot: { request in
            if case .open = request.intent { true } else { false }
        },
        resolver: { request, _ in try viewController(for: route(for: request)) }
    )

    /// How other modules, and the navigator's stack, refer to `issue`.
    static func ref(for issue: Issue) -> EntityRef {
        EntityRef(target: .issues, id: issue.id.uuidString, title: issue.rowTitle)
    }

    /// The stack entry of `issue`'s detail, pushed by the list that owns its state.
    static func detailRequest(for issue: Issue) -> NavigationRequest {
        NavigationRequest(intent: .open(ref(for: issue)))
    }

    static func route(for request: NavigationRequest) throws -> IssuesNavigationContract.Route {
        guard request.target == IssuesNavigationContract.target else { throw NavigationError.wrongTarget }
        switch request.intent {
        case let .open(ref): return .details(id: ref.id)
        case .browse: return .list
        case .selectSingle: return .picker
        case .compose, .perform, .screen: throw NavigationError.unsupportedIntent
        }
    }

    @MainActor
    static func viewController(for route: IssuesNavigationContract.Route) -> UIViewController {
        switch route {
        case .list:
            return IssuesListHostingController(initialState: IssuesList.State())
        case .picker:
            return IssuesListHostingController(initialState: IssuesList.State(isPicker: true))
        case let .details(id):
            @Shared(.issues) var issues
            guard let uuid = UUID(uuidString: id), let issue = Shared($issues[id: uuid]) else {
                return UIHostingController(rootView: ContentUnavailableView("Issue not found", systemImage: "exclamationmark.triangle"))
            }
            let store = Store(initialState: StandaloneIssueDetail.State(detail: IssuesDetail.State(issue: issue))) {
                StandaloneIssueDetail()
            }
            return UIHostingController(rootView: IssuesDetailView(store: store.scope(state: \.detail, action: \.detail)))
        }
    }
}

/// Issue details opened by another module (Screen B, Screen C, RefPicker) on a stack with no Issues
/// list under it. Deep links don't come here: they open inside the tab's list (`deepLinksToRoot`).
/// The list normally owns deletion; here this wrapper does it, then closes the screen.
@Reducer
struct StandaloneIssueDetail {
    @ObservableState
    struct State: Equatable {
        var detail: IssuesDetail.State
    }

    enum Action {
        case detail(IssuesDetail.Action)
    }

    @Dependency(\.navigator) var navigator

    var body: some ReducerOf<Self> {
        Scope(state: \.detail, action: \.detail) {
            IssuesDetail()
        }
        Reduce { state, action in
            switch action {
            case .detail(.delegate(.deleteRequested)):
                let id = state.detail.issue.id
                @Shared(.issues) var issues
                $issues.withLock { _ = $0.remove(id: id) }
                let navigator = navigator
                return .run { _ in await navigator.complete(with: .dismissed) }
            case .detail:
                return .none
            }
        }
    }
}
