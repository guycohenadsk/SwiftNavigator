/// A value a screen sends back while it stays up, typed by the screen's contract (e.g.
/// `ScreenCNavigationContract.Output`). Boxed so `NavigationCore` needs no module's types, and the
/// caller reads it back with `as(_:)` — or skips it with `pushForOutputs(_:as:)`.
public struct NavigationOutput: Hashable, Sendable {
    private let value: any Hashable & Sendable

    public init(_ value: some Hashable & Sendable) {
        self.value = value
    }

    /// The value, if it is a `T`.
    public func `as`<T>(_: T.Type) -> T? {
        value as? T
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.value) == AnyHashable(rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(value))
    }
}
