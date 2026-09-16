import AppRoutes
import Foundation
import Observation

/// Something that can host a modally-presented destination on top of itself. Implemented by both
/// `AppNavigator` (the tab-bar level) and `PresentedNavigator` (each modal level), so presenting
/// while already presenting simply grows the chain instead of replacing it.
@MainActor
protocol PresentationHost: AnyObject {
    var presented: PresentedNavigator? { get set }
}

extension PresentationHost {
    /// Presents `destination` on top of whichever level is currently innermost, so calling
    /// `present` again while something is already presented stacks a new modal rather than
    /// replacing it.
    func present(_ destination: Destination) {
        if let presented {
            presented.present(destination)
        } else {
            presented = PresentedNavigator(destination: destination)
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

/// One level of modal presentation: the destination it was presented with, its own backstack, and
/// optionally another `PresentedNavigator` presented on top of it.
@MainActor
@Observable
final class PresentedNavigator: Navigator, PresentationHost, @unchecked Sendable, Identifiable {
    let id = UUID()
    let destination: Destination
    var path: [RouteEntry] = []
    var presented: PresentedNavigator?

    init(destination: Destination) {
        self.destination = destination
    }

    func push(_ destination: Destination) {
        if let presented { presented.push(destination) } else { path.append(RouteEntry(destination: destination)) }
    }

    func pop() {
        if let presented { presented.pop() } else { _ = path.popLast() }
    }

    func popToRoot() {
        if let presented { presented.popToRoot() } else { path.removeAll() }
    }
}

/// Owns one backstack per tab and mutates whichever tab is currently selected. This is the only
/// piece of the whole system that knows navigation is implemented as four arrays of `RouteEntry`.
@MainActor
@Observable
final class AppNavigator: Navigator, PresentationHost, @unchecked Sendable {
    var tabIndex = 0
    var pathA: [RouteEntry] = []
    var pathB: [RouteEntry] = []
    var pathC: [RouteEntry] = []
    var pathD: [RouteEntry] = []

    var presented: PresentedNavigator?

    func push(_ destination: Destination) {
        if let presented {
            presented.push(destination)
            return
        }
        let entry = RouteEntry(destination: destination)
        switch tabIndex {
        case 0: pathA.append(entry)
        case 1: pathB.append(entry)
        case 2: pathC.append(entry)
        default: pathD.append(entry)
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
