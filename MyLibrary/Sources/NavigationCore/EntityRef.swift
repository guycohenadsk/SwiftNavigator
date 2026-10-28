/// A reference to one entity owned by some module — enough to open it or report it as a selection,
/// without the caller importing that module's model types.
public struct EntityRef: Hashable, Codable, Sendable {
    public let target: NavigationTarget
    public let id: String
    public let title: String

    public init(target: NavigationTarget, id: String, title: String) {
        self.target = target
        self.id = id
        self.title = title
    }
}
