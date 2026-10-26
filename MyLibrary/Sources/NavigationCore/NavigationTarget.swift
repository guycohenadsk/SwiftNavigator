/// Every module that takes part in navigation. Adding a module adds one case here — the one shared
/// edit — and the composition test fails until the app registers it.
public enum NavigationTarget: String, Hashable, Codable, Sendable, CaseIterable {
    case issues
    /// The Issues list that keeps its detail's state and scopes the detail's store from its own
    /// (`IssuesScopeList`); a second tab next to `.issues` for comparison.
    case issuesScope = "issues-scope"
    case screenB
    case screenC
    case screenD
}
