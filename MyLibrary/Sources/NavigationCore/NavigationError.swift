public enum NavigationError: Error, Equatable {
    case wrongTarget
    /// The module does not offer this intent (e.g. `.compose` to a module that takes no text).
    case unsupportedIntent
    case duplicateRegistration(NavigationTarget)
    case unregisteredTarget(NavigationTarget)
}
