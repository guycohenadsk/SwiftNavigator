import NavigationCore
@testable import NavigatorDependency
import Observation
import Testing
import UIKit
import UIKitNavigation

/// Records local pushes and removals, and lets a test play the user leaving a pushed entry.
@MainActor
final class LocalPushSpy: Navigator {
    struct LocalPush {
        let id: NavigationEntry.ID
        let request: NavigationRequest
        let origin: UIViewController
        let screen: @MainActor () -> UIViewController
        let onDismiss: @MainActor () -> Void
    }

    private(set) var pushes: [LocalPush] = []
    private(set) var removed: [NavigationEntry.ID] = []
    /// Pushes and removals in the order they happened.
    private(set) var events: [String] = []

    func push(
        local request: NavigationRequest,
        from origin: UIViewController,
        screen: @escaping @MainActor () -> UIViewController,
        onDismiss: @escaping @MainActor () -> Void
    ) -> NavigationEntry.ID {
        let push = LocalPush(id: NavigationEntry.ID(), request: request, origin: origin, screen: screen, onDismiss: onDismiss)
        pushes.append(push)
        events.append("push \(request.target.rawValue)/\(pushes.count)")
        return push.id
    }

    func remove(_ id: NavigationEntry.ID) {
        removed.append(id)
        events.append("remove \(pushes.firstIndex { $0.id == id }.map { $0 + 1 } ?? 0)")
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

/// Lets `observe` deliver a change; it reacts on the next main-actor turn.
@MainActor
func settle() async {
    for _ in 0..<20 { await Task.yield() }
}

func request(for child: Child) -> NavigationRequest {
    NavigationRequest(intent: .open(EntityRef(target: .issues, id: "\(child.id)", title: child.title)))
}

@MainActor
@Suite("navigatorDestination")
struct NavigatorDestinationTests {
    let parent = Parent()
    let spy = LocalPushSpy()
    let host = UIViewController()
    let token: ObserveToken

    init() {
        let model = UIBindable(parent)
        token = host.navigatorDestination(
            item: model.child,
            navigator: spy,
            id: \.id,
            request: request(for:)
        ) { child in
            let controller = UIViewController()
            controller.title = child.title
            return controller
        }
    }

    @Test("Setting the child pushes one local entry named by its request, from the host")
    func pushesOnSet() async {
        parent.child = Child(id: 1, title: "One")
        await settle()

        #expect(spy.pushes.count == 1)
        #expect(spy.pushes.first?.request == request(for: Child(id: 1, title: "One")))
        #expect(spy.pushes.first?.origin === host)
        #expect(spy.pushes.first?.screen().title == "One")
        #expect(spy.removed.isEmpty)
    }

    @Test("Editing the child without changing its id leaves the entry alone")
    func editKeepsEntry() async {
        parent.child = Child(id: 1, title: "One")
        await settle()
        parent.child?.title = "One, edited"
        await settle()

        #expect(spy.pushes.count == 1)
        #expect(spy.removed.isEmpty)
    }

    @Test("Clearing the child removes its entry; a late onDismiss for it changes nothing")
    func clearRemoves() async throws {
        parent.child = Child(id: 1, title: "One")
        await settle()
        let push = try #require(spy.pushes.first)

        parent.child = nil
        await settle()
        #expect(spy.removed == [push.id])

        parent.child = Child(id: 2, title: "Two")
        await settle()
        push.onDismiss()   // the removed entry's dismissal arriving late
        #expect(parent.child?.id == 2)
    }

    @Test("A child with another id replaces the entry")
    func newIDReplaces() async throws {
        parent.child = Child(id: 1, title: "One")
        await settle()
        let first = try #require(spy.pushes.first)

        parent.child = Child(id: 2, title: "Two")
        await settle()

        #expect(spy.removed == [first.id])
        #expect(spy.pushes.map(\.request) == [request(for: Child(id: 1, title: "One")), request(for: Child(id: 2, title: "Two"))])
    }

    @Test("The entry leaving on its own clears the child, without removing anything")
    func dismissClears() async throws {
        parent.child = Child(id: 1, title: "One")
        await settle()
        let push = try #require(spy.pushes.first)

        push.onDismiss()   // back button / swipe-back / deep-link reset
        await settle()

        #expect(parent.child == nil)
        #expect(spy.removed.isEmpty)
        #expect(spy.pushes.count == 1)
    }

    @Test("After the entry left, setting the child again pushes a fresh entry")
    func reopenAfterDismiss() async throws {
        parent.child = Child(id: 1, title: "One")
        await settle()
        try #require(spy.pushes.first).onDismiss()
        await settle()

        parent.child = Child(id: 1, title: "One")
        await settle()

        #expect(spy.pushes.count == 2)
    }
}

/// A presentation over the child (e.g. a delete alert) still on screen while the parent clears or
/// replaces the child: the entry's removal waits for it, and the next child waits for the removal.
@MainActor
@Suite("navigatorDestination with a presentation over the child")
struct NavigatorDestinationSettleTests {
    let parent = Parent()
    let spy = LocalPushSpy()
    let host = UIViewController()
    /// Removals waiting for the presentation over their screen to go away.
    let held = HeldRemovals()
    let token: ObserveToken

    @MainActor
    final class HeldRemovals {
        var works: [@MainActor () -> Void] = []
        func release() {
            let works = self.works
            self.works = []
            works.forEach { $0() }
        }
    }

    init() {
        let held = held
        token = host.navigatorDestination(
            item: UIBindable(parent).child,
            navigator: spy,
            id: \.id,
            request: request(for:),
            content: { _ in UIViewController() },
            settle: { _, work in held.works.append(work) }
        )
    }

    @Test("Clearing the child removes the entry only once the presentation settles")
    func clearWaits() async {
        parent.child = Child(id: 1, title: "One")
        await settle()

        parent.child = nil
        await settle()
        #expect(spy.removed.isEmpty)

        held.release()
        #expect(spy.removed == [spy.pushes[0].id])
    }

    @Test("A new child set while the old removal waits is pushed after that removal, not before")
    func replaceWaits() async {
        parent.child = Child(id: 1, title: "One")
        await settle()

        parent.child = Child(id: 2, title: "Two")
        await settle()
        #expect(spy.events == ["push issues/1"])

        held.release()
        #expect(spy.events == ["push issues/1", "remove 1", "push issues/2"])
        #expect(parent.child?.id == 2)
    }

    @Test("A child cleared while waiting behind a removal is never pushed")
    func pendingPushCancelled() async {
        parent.child = Child(id: 1, title: "One")
        await settle()

        parent.child = Child(id: 2, title: "Two")
        await settle()
        parent.child = nil
        await settle()

        held.release()
        #expect(spy.events == ["push issues/1", "remove 1"])
    }

    @Test("The child pushed after a waited removal still clears the parent when it leaves")
    func queuedPushDismisses() async throws {
        parent.child = Child(id: 1, title: "One")
        await settle()
        parent.child = Child(id: 2, title: "Two")
        await settle()
        held.release()

        try #require(spy.pushes.last).onDismiss()
        await settle()

        #expect(parent.child == nil)
    }
}
