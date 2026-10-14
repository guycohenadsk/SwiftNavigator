/// The serializable heart of every request: what the caller wants, in terms any module understands.
/// Deep links can only express intents, so anything reachable from a URL must be expressible here.
public enum NavigationIntent: Hashable, Codable, Sendable {
    /// Show one entity.
    case open(EntityRef)
    /// Show the module's main screen.
    case browse(NavigationTarget)
    /// Let the user pick one entity of the module and report it back.
    case selectSingle(NavigationTarget)
    /// Ask the module for text, showing `prompt`. Replies arrive as `.message` updates.
    case compose(NavigationTarget, prompt: String)
    /// Ask the module to run one of its named actions (`NavigationRegistration.actions`), e.g. from
    /// `demoapp://issues?action=screenCContext`.
    case perform(NavigationTarget, action: String)
}
