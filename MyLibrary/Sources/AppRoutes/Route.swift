/// Every screen any tab's stack can push to, regardless of which UI framework renders it.
public enum Route: Hashable, Sendable, CaseIterable {
    case issues
    case screenB
    case screenC
    case screenD

    public var title: String {
        switch self {
        case .issues: "Issues"
        case .screenB: "Screen B"
        case .screenC: "Screen C"
        case .screenD: "Screen D"
        }
    }

    public var subtitle: String {
        switch self {
        case .issues, .screenB: "SwiftUI + TCA"
        case .screenC, .screenD: "UIKit"
        }
    }
}
