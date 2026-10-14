import ComposableArchitecture
import NavigationCore
import NavigatorDependency
import Testing

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
}

private let issue = EntityRef(target: .issues, id: "issue-2", title: "#931")

@MainActor
@Suite("RefPicker")
struct RefPickerTests {
    @Test("Tapping a reference opens it")
    func tapOpens() async {
        let spy = NavigatorSpy()
        let item = ReferenceItem(id: "issue-1", target: .issues, title: "#928")
        let store = TestStore(initialState: RefPicker.State(target: .issues, references: [item])) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
        }

        await store.send(.referenceTapped(item))
        await store.finish()

        #expect(spy.pushed == [NavigationRequest(intent: .open(EntityRef(target: .issues, id: "issue-1", title: "#928")))])
    }

    @Test("Add Reference pushes the target's picker and appends the pick")
    func addAppends() async {
        let spy = NavigatorSpy()
        spy.result = .selectedEntity(issue)
        let store = TestStore(initialState: RefPicker.State(target: .issues)) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
        }

        await store.send(.addReferenceTapped)
        await store.receive(\.referenceAdded) {
            $0.references = [ReferenceItem(id: "issue-2", target: .issues, title: "#931")]
        }
        #expect(spy.pushed == [NavigationRequest(intent: .selectSingle(.issues))])
    }

    @Test("Dismissing the picker adds nothing")
    func dismissAddsNothing() async {
        let spy = NavigatorSpy()
        let store = TestStore(initialState: RefPicker.State(target: .issues)) {
            RefPicker()
        } withDependencies: {
            $0.navigator = spy
        }

        await store.send(.addReferenceTapped)
        await store.finish()
    }

    @Test("Picking an issue that is already referenced does not duplicate it")
    func noDuplicates() async {
        let existing = ReferenceItem(id: "issue-2", target: .issues, title: "#931")
        let store = TestStore(initialState: RefPicker.State(target: .issues, references: [existing])) {
            RefPicker()
        }

        await store.send(.referenceAdded(issue))
    }
}
