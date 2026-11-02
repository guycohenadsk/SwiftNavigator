public enum DeepLinkError: Error, Equatable {
    case unsupportedScheme
    case unknownTarget
    /// The module is known but offers nothing for this path or query.
    case unsupportedLink
}
