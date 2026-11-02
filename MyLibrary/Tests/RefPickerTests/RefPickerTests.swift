import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import Testing
import UIKit

@testable import RefPicker

/// Records pushes, and answers every push that asks for a result with `result`.
@MainActor
private final class NavigatorSpy: Navigator {
    var result: NavigationResult = .dismissed
    private(set) var pushed: [NavigationRequest] = []

    func push(_ request: NavigationRequest, onResult: NavigationResultHandler?) {
        pushed.append(request)
        onResult?(result)
    }
    func present(_ request: NavigationRequest, onResult: NavigationResultHandler?) {}
    func send(_ result: NavigationResult) {}
    func complete(with result: NavigationResult) {}
    func pop() {}
    func popToRoot() {}
    func dismiss() {}
    func incomingRequests(for target: NavigationTarget) -> AsyncStream<NavigationRequest> { AsyncStream { $0.finish() } }
}

/// Test-local routes: RefPicker knows no module's contract.
private enum TestRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case open(String)
}

private enum PickRoute: NavigationRoute {
    static let target = NavigationTarget.issues
    case pick
}

private enum OtherRoute: NavigationRoute {
    static let target = NavigationTarget.screenD
    case pick
}

private let issuePicker = NavigationPicker(title: "Issue", route: PickRoute.pick)
private let pickRequest = issuePicker.request
private func entity(_ id: String, _ title: String) -> EntityRef {
    EntityRef(id: id, title: title, open: NavigationRequest(TestRoute.open(id)))
}

private let issue = entity("issue-2", "#931")

@MainActor
@Suite("RefPicker")
struct RefPickerTests {
    @Test("Tapping a reference opens it")
    func tapOpens() async {
        let spy = NavigatorSpy()
        let item = ReferenceItem(entity("issue-1", "#928"))
        let store = TestStore(initialState: RefPicker.State(references: [item])) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
            $0.navigationPickers = [issuePicker]
        }

        await store.send(.referenceTapped(item))
        await store.finish()

        #expect(spy.pushed == [NavigationRequest(TestRoute.open("issue-1"))])
    }

    @Test("Add Reference pushes the pick request and appends the pick")
    func addAppends() async {
        let spy = NavigatorSpy()
        spy.result = .selectedEntity(issue)
        let store = TestStore(initialState: RefPicker.State()) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
            $0.navigationPickers = [issuePicker]
        }

        await store.send(.addReferenceTapped)
        await store.receive(\.referenceAdded) {
            $0.references = [ReferenceItem(issue)]
        }
        #expect(spy.pushed == [pickRequest])
    }

    @Test("With several pickers, Add Reference asks which one, then picks from it")
    func choosePicker() async {
        let spy = NavigatorSpy()
        spy.result = .selectedEntity(issue)
        let otherPicker = NavigationPicker(title: "Other", route: OtherRoute.pick)
        let other = otherPicker.request
        let store = TestStore(initialState: RefPicker.State()) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
            $0.navigationPickers = [issuePicker, otherPicker]
        }

        await store.send(.addReferenceTapped) {
            $0.chooser = ConfirmationDialogState(title: { TextState("Add Reference") }) {
                ButtonState(action: .source(.issues)) { TextState("Issue") }
                ButtonState(action: .source(.screenD)) { TextState("Other") }
            }
        }
        #expect(spy.pushed.isEmpty)

        await store.send(.chooser(.presented(.source(.screenD)))) { $0.chooser = nil }
        await store.receive(\.referenceAdded) {
            $0.references = [ReferenceItem(issue)]
        }
        #expect(spy.pushed == [other])
    }

    @Test("Without pickers, Add Reference does nothing")
    func noPickers() async {
        let spy = NavigatorSpy()
        let store = TestStore(initialState: RefPicker.State()) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
            $0.navigationPickers = []
        }

        await store.send(.addReferenceTapped)
        #expect(spy.pushed.isEmpty)
    }

    @Test("Dismissing the picker adds nothing")
    func dismissAddsNothing() async {
        let spy = NavigatorSpy()
        let store = TestStore(initialState: RefPicker.State()) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
            $0.navigationPickers = [issuePicker]
        }

        await store.send(.addReferenceTapped)
        await store.finish()
    }

    @Test("Picking an issue that is already referenced does not duplicate it")
    func noDuplicates() async {
        let existing = ReferenceItem(issue)
        let store = TestStore(initialState: RefPicker.State(references: [existing])) {
            RefPicker()
        } withDependencies: {
            $0.navigationPickers = [issuePicker]
        }

        await store.send(.referenceAdded(issue))
    }
}
