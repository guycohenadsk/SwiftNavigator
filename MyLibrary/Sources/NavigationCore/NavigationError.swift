public enum NavigationError: Error, Equatable {
    case wrongTarget
    case duplicateRegistration(NavigationTarget)
    case unregisteredTarget(NavigationTarget)
}
