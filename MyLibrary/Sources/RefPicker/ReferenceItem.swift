import NavigationCore

public struct ReferenceItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let target: NavigationTarget
    public let title: String

    public init(id: String, target: NavigationTarget, title: String) {
        self.id = id
        self.target = target
        self.title = title
    }
}
