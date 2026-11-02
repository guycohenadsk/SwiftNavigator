/// Every module that takes part in navigation. Adding a module adds one case here — the one shared
/// edit — and the composition test fails until the app registers it.
public enum NavigationTarget: String, Hashable, Codable, Sendable, CaseIterable {
    case issues
    case screenB
    case screenC
    case screenD
    case rfi
}
