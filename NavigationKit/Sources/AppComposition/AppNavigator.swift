import AppRoutes
import Foundation
import Observation

/// Something that can host a modally-presented `Route` on top of itself. Implemented by both
/// `AppNavigator` (the tab-bar level) and `PresentedNavigator` (each modal level), so presenting
/// while already presenting simply grows the chain instead of replacing it.
@MainActor
protocol PresentationHost: AnyObject {
    var presented: PresentedNavigator? { get set }
}

extension PresentationHost {
    /// Presents `route` on top of whichever level is currently innermost, so calling `present`
    /// again while something is already presented stacks a new modal rather than replacing it.
    func present(_ route: Route) {
        if let presented {
            presented.present(route)
        } else {
            presented = PresentedNavigator(route: route)
        }
    }

    /// Dismisses only the innermost presented level, leaving any levels beneath it untouched.
    func dismiss() {
        if let presented, presented.presented != nil {
            presented.dismiss()
        } else {
            presented = nil
        }
    }
}

/// One level of modal presentation: the route it was presented with, its own backstack, and
/// optionally another `PresentedNavigator` presented on top of it.
@MainActor
@Observable
final class PresentedNavigator: Navigator, PresentationHost, @unchecked Sendable, Identifiable {
    let id = UUID()
    let route: Route
    var path: [Route] = []
    var presented: PresentedNavigator?

    init(route: Route) {
        self.route = route
    }

    func push(_ route: Route) {
        if let presented { presented.push(route) } else { path.append(route) }
    }

    func pop() {
        if let presented { presented.pop() } else { _ = path.popLast() }
    }

    func popToRoot() {
        if let presented { presented.popToRoot() } else { path.removeAll() }
    }
}

/// Owns one backstack per tab and mutates whichever tab is currently selected. This is the only
/// piece of the whole system that knows navigation is implemented as four arrays of `Route`.
@MainActor
@Observable
final class AppNavigator: Navigator, PresentationHost, @unchecked Sendable {
    var tabIndex = 0
    var pathA: [Route] = []
    var pathB: [Route] = []
    var pathC: [Route] = []
    var pathD: [Route] = []

    var presented: PresentedNavigator?

    func push(_ route: Route) {
        if let presented {
            presented.push(route)
            return
        }
        switch tabIndex {
        case 0: pathA.append(route)
        case 1: pathB.append(route)
        case 2: pathC.append(route)
        default: pathD.append(route)
        }
    }

    func pop() {
        if let presented {
            presented.pop()
            return
        }
        switch tabIndex {
        case 0: _ = pathA.popLast()
        case 1: _ = pathB.popLast()
        case 2: _ = pathC.popLast()
        default: _ = pathD.popLast()
        }
    }

    func popToRoot() {
        if let presented {
            presented.popToRoot()
            return
        }
        switch tabIndex {
        case 0: pathA.removeAll()
        case 1: pathB.removeAll()
        case 2: pathC.removeAll()
        default: pathD.removeAll()
        }
    }
}
