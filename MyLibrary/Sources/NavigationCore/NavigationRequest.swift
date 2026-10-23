public struct NavigationRequest: Hashable, Codable, Sendable {
    public let intent: NavigationIntent

    /// Derived from the intent, so target and intent can never disagree.
    public var target: NavigationTarget {
        switch intent {
        case let .open(ref): ref.target
        case let .browse(target): target
        case let .selectSingle(target): target
        case let .compose(target, _): target
        case let .perform(target, _): target
        case let .screen(target, _): target
        }
    }

    public init(intent: NavigationIntent) {
        self.intent = intent
    }
}
