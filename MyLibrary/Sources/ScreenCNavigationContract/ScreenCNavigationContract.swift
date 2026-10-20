import NavigationCore

/// Screen C's routes, and the outputs it sends back in compose mode. Screen C imports it to send;
/// callers import it to read what comes back — never Screen C itself.
public enum ScreenCNavigationContract {
    public static let target: NavigationTarget = .screenC

    public enum Route: Hashable {
        case home
        /// A text field and Send; each Send goes back to the caller as an `Output`.
        case compose(prompt: String)
    }

    /// What Screen C sends whoever opened it in compose mode, as `.output` updates.
    public enum Output: Hashable, Sendable {
        case textSubmitted(String)
    }

    /// Opens Screen C in compose mode; read its replies with `pushForOutputs(_:as: Output.self)`.
    public static func compose(prompt: String) -> NavigationRequest {
        NavigationRequest(intent: .compose(target, prompt: prompt))
    }
}
