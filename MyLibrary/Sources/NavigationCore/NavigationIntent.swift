/// The serializable heart of every request: what the caller wants, in terms any module understands.
/// Deep links can only express intents, so anything reachable from a URL must be expressible here.
public enum NavigationIntent: Hashable, Codable, Sendable {
    /// Show one entity.
    case open(EntityRef)
    /// Show the module's main screen.
    case browse(NavigationTarget)
    /// Let the user pick one entity of the module and report it back.
    case selectSingle(NavigationTarget)
    /// Ask the module for text, showing `prompt`. Replies arrive as `.output` updates, typed
    /// by the module's contract.
    case compose(NavigationTarget, prompt: String)
    /// One of the module's own inner screens, named by the module (e.g. Screen B's `"b2"`). Pushed by
    /// the module itself as a local entry (`Navigator.push(local:…)`), so the stack stays all data;
    /// other modules have no reason to ask for it.
    case screen(NavigationTarget, name: String)
    /// Ask the module to run one of its named actions, e.g. from
    /// `demoapp://issues?action=screenCContext`. Delivered through `Navigator.incomingRequests(for:)`.
    case perform(NavigationTarget, action: String)
}
