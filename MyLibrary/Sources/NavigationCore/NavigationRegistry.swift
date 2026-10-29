import Foundation
import UIKit

@MainActor
public final class NavigationRegistry {
    private var registrations: [NavigationTarget: NavigationRegistration] = [:]

    public init() {}

    public func register(_ registration: NavigationRegistration) throws {
        guard registrations[registration.target] == nil else {
            throw NavigationError.duplicateRegistration(registration.target)
        }
        registrations[registration.target] = registration
    }

    /// Whether the module `request` targets wants this deep link handed to its root screen.
    public func deepLinksToRoot(_ request: NavigationRequest) -> Bool {
        registrations[request.target]?.deepLinksToRoot(request) ?? false
    }

    public var registeredTargets: Set<NavigationTarget> {
        Set(registrations.keys)
    }

    public func resolve(_ request: NavigationRequest, context: NavigationContext) throws -> UIViewController {
        guard let registration = registrations[request.target] else {
            throw NavigationError.unregisteredTarget(request.target)
        }
        return try registration.resolver(request, context)
    }

    /// Resolves `request` with no parent, as a stack's root.
    public func resolve(_ request: NavigationRequest, navigator: any Navigator) throws -> UIViewController {
        try resolve(request, context: NavigationContext(navigator: navigator))
    }

    /// `demoapp://<target>/...` → the request the target's registration makes of it. The scheme and
    /// target are checked here; the rest of the URL is the module's own grammar.
    public func request(for url: URL) throws -> NavigationRequest {
        guard url.scheme == "demoapp" else { throw DeepLinkError.unsupportedScheme }
        guard let host = url.host(), let target = NavigationTarget(rawValue: host) else {
            throw DeepLinkError.unknownTarget
        }
        guard let registration = registrations[target] else { throw NavigationError.unregisteredTarget(target) }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value ?? "" } ?? [:]
        let link = DeepLink(target: target, path: url.pathComponents.filter { $0 != "/" }, query: query)
        guard let request = registration.deepLink(link) else { throw DeepLinkError.unsupportedLink }
        return request
    }
}
