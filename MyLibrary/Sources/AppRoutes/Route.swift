/// Every screen any tab's stack can push to, regardless of which UI framework renders it.
public enum Route: Hashable, Sendable, CaseIterable {
    case screenA
    case screenB
    case screenC
    case screenD

    public var title: String {
        switch self {
        case .screenA: "Screen A"
        case .screenB: "Screen B"
        case .screenC: "Screen C"
        case .screenD: "Screen D"
        }
    }

    public var subtitle: String {
        switch self {
        case .screenA, .screenB: "SwiftUI + TCA"
        case .screenC, .screenD: "UIKit"
        }
    }
}
