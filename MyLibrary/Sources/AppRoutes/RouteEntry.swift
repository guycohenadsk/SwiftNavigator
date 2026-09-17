import Foundation

/// One occurrence of a destination on a navigation stack. Equality and hashing use only `id`, the
/// same move TCA's `StackState` makes: the stack diffing machinery needs to tell two pushes of the
/// same screen apart, and it means `Destination` payloads (like delegate closures) never need to
/// be `Hashable` themselves.
public struct RouteEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let destination: Destination

    public init(id: UUID = UUID(), destination: Destination) {
        self.id = id
        self.destination = destination
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
