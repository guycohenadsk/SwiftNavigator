import Foundation

/// `demoapp://<target>` → `.browse(target)`; `demoapp://<target>/<id>` → `.open(EntityRef)`;
/// `demoapp://<target>?action=<name>` → `.perform(target, action: name)`.
/// Knows no module by name — `NavigationTarget(rawValue:)` does the lookup.
public enum DeepLinkParser {
    public static func parse(_ url: URL) throws -> NavigationRequest {
        guard url.scheme == "demoapp" else {
            throw DeepLinkError.unsupportedScheme
        }
        guard let host = url.host(), let target = NavigationTarget(rawValue: host) else {
            throw DeepLinkError.unknownTarget
        }
        if let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "action" })?.value, !action.isEmpty {
            return NavigationRequest(intent: .perform(target, action: action))
        }
        let components = url.pathComponents.filter { $0 != "/" }
        if let entityID = components.first, !entityID.isEmpty {
            return NavigationRequest(intent: .open(EntityRef(target: target, id: entityID, title: "")))
        }
        return NavigationRequest(intent: .browse(target))
    }
}
