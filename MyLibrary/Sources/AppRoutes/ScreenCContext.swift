/// Everything a caller can hand Screen C when pushing it: optional display input, and a delegate
/// closure for events flowing back. Lives in the routes module because it's part of the navigation
/// contract — the caller and Screen C never import each other.
public struct ScreenCContext: Sendable {
    public let subtitle: String?
    public let output: @MainActor @Sendable (ScreenCOutput) -> Void

    public init(
        subtitle: String? = nil,
        output: @escaping @MainActor @Sendable (ScreenCOutput) -> Void = { _ in }
    ) {
        self.subtitle = subtitle
        self.output = output
    }
}

/// Events Screen C reports back to whoever pushed it.
public enum ScreenCOutput: Sendable {
    case textSubmitted(String)
}
