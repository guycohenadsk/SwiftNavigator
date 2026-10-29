/// A reference to one entity owned by some module — enough to show it or report it as a selection,
/// without the caller importing that module's model types. The owning module says how to open it
/// (`open`), so anyone holding the reference, such as a shared component, can open it without
/// knowing the module's routes.
public struct EntityRef: Hashable, Sendable {
    public let id: String
    public let title: String
    /// The request that opens this entity, built by the module that owns it.
    public let open: NavigationRequest

    public var target: NavigationTarget { open.target }

    public init(id: String, title: String, open: NavigationRequest) {
        self.id = id
        self.title = title
        self.open = open
    }
}
