/// What a screen reports to whoever opened it.
///
/// A handler receives any number of `.output` updates (sent while the screen stays up), then
/// exactly one final result: `.selectedEntity` or `.dismissed`.
public enum NavigationResult: Hashable, Sendable {
    case selectedEntity(EntityRef)
    /// An update sent with `Navigator.send(_:)`; the screen stays on screen.
    case output(NavigationOutput)
    /// The screen left without a result: popped, swiped away, dismissed, or reset by a deep link.
    case dismissed

    /// Whether this ends the handler. `.output` never does.
    public var isFinal: Bool {
        if case .output = self { false } else { true }
    }

    /// The update's value, if this is an `.output` carrying a `T`.
    public func output<T>(as type: T.Type) -> T? {
        if case let .output(output) = self { output.as(type) } else { nil }
    }
}
