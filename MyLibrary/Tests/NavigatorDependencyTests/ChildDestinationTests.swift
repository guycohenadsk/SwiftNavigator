import NavigationCore
import Observation
import Testing
import UIKit
import UIKitNavigation

@testable import NavigatorDependency

/// Records local pushes, presentations and removals, and lets a test play the user leaving one.
@MainActor
final class LocalPushSpy: Navigator {
    struct LocalEntry {
        let id: NavigationEntry.ID
        let request: NavigationRequest
        let origin: UIViewController?
        let screen: @MainActor () -> UIViewController
        let onDismiss: @MainActor () -> Void
    }

    private(set) var entries: [LocalEntry] = []
    private(set) var removed: [NavigationEntry.ID] = []
    /// Pushes, presentations and removals in the order they happened.
    private(set) var events: [String] = []

    func push(
        local request: NavigationRequest,
        from origin: UIViewController,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        record("push", request, origin: origin, screen: screen, onDismiss: onDismiss)
    }

    func present(
        local request: NavigationRequest,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        record("present", request, origin: nil, screen: screen, onDismiss: onDismiss)
    }

    private func record(
        _ kind: String, _ request: NavigationRequest, origin: UIViewController?,
        screen: @escaping @MainActor () -> UIViewController, onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        let entry = LocalEntry(id: NavigationEntry.ID(), request: request, origin: origin, screen: screen, onDismiss: onDismiss)
        entries.append(entry)
        if case let .open(ref) = request.intent { events.append("\(kind) \(ref.id)") }
        return entry.id
    }

    func remove(_ id: NavigationEntry.ID) {
        removed.append(id)
        if let entry = entries.first(where: { $0.id == id }), case let .open(ref) = entry.request.intent {
            events.append("remove \(ref.id)")
        }
    }

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { $0.finish() } }
}

struct Child: Equatable {
    var id: Int
    var title: String
}

@MainActor
@Observable
final class Parent {
    var child: Child?
}

/// Lets `observe` deliver a change; it reacts on a later main-actor turn.
@MainActor
func settle() async {
    for _ in 0..<20 { await Task.yield() }
}

func request(for child: Child) -> NavigationRequest {
    NavigationRequest(intent: .open(EntityRef(target: .issues, id: "\(child.id)", title: "")))
}

/// Work held back until a test releases it — stands in for a presentation settling.
@MainActor
final class HeldWork {
    var works: [@MainActor () -> Void] = []

    func release() {
        let works = self.works
        self.works = []
        works.forEach { $0() }
    }
}

/// A parent screen with one child destination, its ChildNavigator, and a spy app navigator.
@MainActor
struct Harness {
    let parent = Parent()
    let spy = LocalPushSpy()
    let children = ChildNavigator()
    let host = UIViewController()
    /// Removals waiting for a presentation over their screen to settle; empty unless `holdsRemovals`.
    let held = HeldWork()
    let token: ObserveToken

    init(holdsRemovals: Bool = false) {
        children.missingPushGrace = nil
        let held = held
        token = host.childDestination(
            item: UIBindable(parent).child,
            children: children,
            navigator: spy,
            id: \.id,
            request: request(for:),
            content: { child in
                let controller = UIViewController()
                controller.title = child.title
                return controller
            },
            settle: { _, work in
                if holdsRemovals { held.works.append(work) } else { work() }
            }
        )
    }

    /// Sets the child, then pushes it — what a reducer does in one action.
    func open(_ child: Child, as presentation: ChildPresentation = .push) {
        parent.child = child
        children.push(request(for: child), as: presentation)
    }
}

@MainActor
@Suite("childDestination")
struct ChildDestinationTests {
    @Test("Setting state and pushing shows one local entry, named by its request, from the host")
    func pushShows() throws {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))

        let entry = try #require(h.spy.entries.first)
        #expect(h.spy.events == ["push 1"])
        #expect(entry.origin === h.host)
        #expect(entry.screen().title == "One")
        #expect(h.children.history == [ChildPush(request(for: Child(id: 1, title: "One")))])
    }

    @Test("Presenting shows the child in a new modal instead")
    func presentShows() {
        let h = Harness()
        h.open(Child(id: 1, title: "One"), as: .present)
        #expect(h.spy.events == ["present 1"])
    }

    @Test("Pushing the same child twice shows it once")
    func pushTwice() {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        h.children.push(request(for: Child(id: 1, title: "One")))
        #expect(h.spy.events == ["push 1"])
    }

    @Test("State set without a push shows nothing, and is reported as missing its push")
    func stateWithoutPush() async {
        let h = Harness()
        h.parent.child = Child(id: 1, title: "One")
        await settle()

        #expect(h.spy.entries.isEmpty)
        withKnownIssue {
            h.children.reportMissingPushes()
        }
    }

    @Test("A push no state matches is reported and ignored")
    func pushWithoutState() {
        let h = Harness()
        withKnownIssue {
            h.children.push(request(for: Child(id: 1, title: "One")))
        }
        h.parent.child = Child(id: 2, title: "Two")
        withKnownIssue {
            h.children.push(request(for: Child(id: 1, title: "One")))
        }
        #expect(h.spy.entries.isEmpty)
    }

    @Test("A pushed child is not reported as missing")
    func pushedNotMissing() {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        h.children.reportMissingPushes()
    }

    @Test("Editing the child without changing its id leaves the entry alone")
    func editKeepsEntry() async {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        await settle()
        h.parent.child?.title = "One, edited"
        await settle()

        #expect(h.spy.events == ["push 1"])
    }

    @Test("The entry leaving on its own clears the state, without removing anything")
    func dismissClears() async throws {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        try #require(h.spy.entries.first).onDismiss()
        await settle()

        #expect(h.parent.child == nil)
        #expect(h.spy.removed.isEmpty)

        h.open(Child(id: 1, title: "One"))
        #expect(h.spy.events == ["push 1", "push 1"])
    }

    @Test("Clearing the state removes the entry; a late onDismiss for it changes nothing")
    func clearRemoves() async throws {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        let entry = try #require(h.spy.entries.first)

        h.parent.child = nil
        await settle()
        #expect(h.spy.events == ["push 1", "remove 1"])

        h.open(Child(id: 2, title: "Two"))
        entry.onDismiss()
        #expect(h.parent.child?.id == 2)
    }

    @Test("Replacing the child and pushing in the same turn removes the old entry first")
    func replaceInOneTurn() async {
        let h = Harness()
        h.open(Child(id: 1, title: "One"))
        await settle()

        h.open(Child(id: 2, title: "Two"))   // before observe has seen the change
        await settle()

        #expect(h.spy.events == ["push 1", "remove 1", "push 2"])
    }

    @Test("A store that wasn't given its own ChildNavigator reports a push")
    func unsetReports() {
        let unset = ChildNavigator(mode: .unset)
        withKnownIssue {
            unset.push(request(for: Child(id: 1, title: "One")))
        }
    }

    @Test("A recording ChildNavigator keeps every push and reports nothing")
    func recordingRecords() {
        let recording = ChildNavigator.recording()
        recording.push(request(for: Child(id: 1, title: "One")), as: .present)
        #expect(recording.history == [ChildPush(request(for: Child(id: 1, title: "One")), .present)])
    }
}

/// A presentation over the child (e.g. a delete alert) still up while the parent clears or replaces
/// it: the removal waits for it, and the next child waits for the removal.
@MainActor
@Suite("childDestination with a presentation over the child")
struct ChildDestinationSettleTests {
    @Test("Clearing the state removes the entry only once the presentation settles")
    func clearWaits() async {
        let h = Harness(holdsRemovals: true)
        h.open(Child(id: 1, title: "One"))

        h.parent.child = nil
        await settle()
        #expect(h.spy.removed.isEmpty)

        h.held.release()
        #expect(h.spy.events == ["push 1", "remove 1"])
    }

    @Test("A new child pushed while the old removal waits is shown after that removal")
    func replaceWaits() async {
        let h = Harness(holdsRemovals: true)
        h.open(Child(id: 1, title: "One"))
        await settle()

        h.open(Child(id: 2, title: "Two"))
        await settle()
        #expect(h.spy.events == ["push 1"])

        h.held.release()
        #expect(h.spy.events == ["push 1", "remove 1", "push 2"])
    }

    @Test("A child cleared while waiting behind a removal is never shown")
    func pendingCancelled() async {
        let h = Harness(holdsRemovals: true)
        h.open(Child(id: 1, title: "One"))
        await settle()

        h.open(Child(id: 2, title: "Two"))
        h.parent.child = nil
        await settle()

        h.held.release()
        #expect(h.spy.events == ["push 1", "remove 1"])
    }

    @Test("The child shown after a waited removal still clears the state when it leaves")
    func queuedDismisses() async throws {
        let h = Harness(holdsRemovals: true)
        h.open(Child(id: 1, title: "One"))
        await settle()
        h.open(Child(id: 2, title: "Two"))
        await settle()
        h.held.release()

        try #require(h.spy.entries.last).onDismiss()
        await settle()
        #expect(h.parent.child == nil)
    }
}
