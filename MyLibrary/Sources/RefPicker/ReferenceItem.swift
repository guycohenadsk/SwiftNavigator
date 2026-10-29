import NavigationCore

public struct ReferenceItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let open: NavigationRequest

    public var target: NavigationTarget { open.target }

    public init(id: String, title: String, open: NavigationRequest) {
        self.id = id
        self.title = title
        self.open = open
    }

    public init(_ entity: EntityRef) {
        self.init(id: entity.id, title: entity.title, open: entity.open)
    }
}
