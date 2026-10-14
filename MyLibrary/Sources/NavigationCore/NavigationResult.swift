/// What a screen reports to whoever opened it.
///
/// A handler receives any number of `.message` updates (sent while the screen stays up), then
/// exactly one final result: `.selectedEntity` or `.dismissed`.
public enum NavigationResult: Hashable, Sendable {
    case selectedEntity(EntityRef)
    /// An update sent with `Navigator.send(_:)`; the screen stays on screen.
    case message(String)
    /// The screen left without a result: popped, swiped away, dismissed, or reset by a deep link.
    case dismissed

    /// Whether this ends the handler. `.message` never does.
    public var isFinal: Bool {
        if case .message = self { false } else { true }
    }
}
