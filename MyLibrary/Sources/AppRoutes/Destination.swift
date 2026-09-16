/// A concrete navigation request: which screen to show, plus whatever input/output contract that
/// screen accepts. `Route` stays the payload-free catalog for "list every screen" UI; `Destination`
/// is what actually travels through the `Navigator`. Screens that take no context simply have no
/// payload, so an illegal pairing (e.g. Screen A carrying Screen C's context) cannot be written.
public enum Destination: Sendable {
    case screenA
    case screenB
    case screenC(ScreenCContext? = nil)
    case screenD

    /// Bridges the catalog into a context-free destination, keeping `navigator.push(route)`
    /// call sites working unchanged.
    public init(_ route: Route) {
        switch route {
        case .screenA: self = .screenA
        case .screenB: self = .screenB
        case .screenC: self = .screenC()
        case .screenD: self = .screenD
        }
    }
}
