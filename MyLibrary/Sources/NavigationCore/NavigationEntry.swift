import Foundation

/// One occurrence of a request on a stack. Identity is the UUID, so the same screen can be pushed
/// twice, and a result handler can be keyed to exactly this push.
public struct NavigationEntry: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let request: NavigationRequest

    public init(id: UUID = UUID(), request: NavigationRequest) {
        self.id = id
        self.request = request
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
