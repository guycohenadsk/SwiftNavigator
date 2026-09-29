import ComposableArchitecture
import Foundation
import Testing

@testable import IssuesDomain

/// Serialized because `.inMemory` file storage is process-wide: parallel tests would otherwise
/// read and write each other's issues.
@MainActor
@Suite("Issues domain", .serialized)
struct IssuesDomainTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// In-memory file storage, reset to the seed, so nothing touches the real
    /// `Documents/issues.json` and every test starts from the same eight issues.
    private func makeListStore() -> TestStoreOf<IssuesList> {
        withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.uuid = .incrementing
            $0.date = .constant(Self.now)
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            return TestStore(initialState: IssuesList.State()) { IssuesList() }
        }
    }

    @Test("Tapping a row opens the detail screen for that issue")
    func tappingRowOpensDetail() async {
        let store = makeListStore()
        let issue = store.state.issues[1]

        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }
    }

    /// The one failure mode that is invisible by hand: if the detail screen held a copy instead of
    /// a `Shared` into the array, this edit would look fine on screen and be lost on the way back.
    @Test("Editing the title in detail writes through to the shared list")
    func editingTitleWritesThrough() async {
        let store = makeListStore()
        let issue = store.state.issues[0]

        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }
        await store.send(.detail(.presented(.titleChanged("Re-commissioning")))) {
            $0.$issues.withLock { $0[id: issue.id]?.title = "Re-commissioning" }
            $0.detail?.$issue.withLock { $0.title = "Re-commissioning" }
        }

        #expect(store.state.issues[id: issue.id]?.title == "Re-commissioning")
    }

    @Test("Confirming delete removes the issue and dismisses detail")
    func deleteRemovesIssue() async {
        let store = makeListStore()
        let issue = store.state.issues[2]
        let countBefore = store.state.issues.count

        await store.send(.issueTapped(issue.id)) {
            $0.detail = IssuesDetail.State(issue: Shared(value: issue))
        }
        await store.send(.detail(.presented(.deleteButtonTapped))) {
            $0.detail?.alert = AlertState {
                TextState("Delete issue?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmDelete) { TextState("Delete") }
                ButtonState(role: .cancel) { TextState("Cancel") }
            } message: {
                TextState("This removes the issue from shared storage. It cannot be undone.")
            }
        }
        // The delegate effect is processed eagerly. Mutations to @Shared state are asserted
        // against live storage, so the removal shows up here; plain state changes are snapshotted
        // and show up on the received action below.
        await store.send(.detail(.presented(.alert(.presented(.confirmDelete))))) {
            $0.detail?.alert = nil
            $0.$issues.withLock { $0.remove(id: issue.id) }
        }
        await store.receive(\.detail.presented.delegate.deleteRequested) {
            $0.detail = nil
        }

        #expect(store.state.issues.count == countBefore - 1)
        #expect(store.state.issues[id: issue.id] == nil)
    }

    @Test("Adding an issue appends it and opens it")
    func addingIssueOpensIt() async {
        let store = makeListStore()
        let new = Issue(id: UUID(0), status: .draft, createdAt: Self.now)

        await store.send(.addIssueTapped) {
            $0.$issues.withLock { $0.append(new) }
            $0.detail = IssuesDetail.State(issue: Shared(value: new))
        }

        #expect(store.state.issues.count == Issue.seed.count + 1)
        #expect(store.state.detail?.issue.id == new.id)
    }

    @Test("Empty fields group only once more than two of them are empty")
    func emptyFieldsGrouping() {
        let sparse = IssuesDetail.State(
            issue: Shared(value: Issue(number: 1, title: "Sparse", status: .open, typeCode: "CM"))
        )
        #expect(sparse.emptyFields.count == 7)
        #expect(sparse.isGroupingEmptyFields)

        // Exactly two empty (root cause and start date) — below the threshold, so everything is inline.
        let nearlyFull = IssuesDetail.State(
            issue: Shared(
                value: Issue(
                    number: 2, title: "Nearly full", status: .open, typeCode: "CM",
                    assigneeName: "john.doe@example.com", issueDescription: "Something",
                    location: "Roof", locationDetails: "Near the hatch", dueDate: Date()
                )
            )
        )
        #expect(nearlyFull.emptyFields.count == 2)
        #expect(!nearlyFull.isGroupingEmptyFields)
        #expect(nearlyFull.inlineFields.count == IssuesDetail.Field.allCases.count)

        // Drafts never group, however empty they are.
        let draft = IssuesDetail.State(issue: Shared(value: Issue(title: "Draft", status: .draft)))
        #expect(draft.emptyFields.count == 7)
        #expect(!draft.isGroupingEmptyFields)
    }

    @Test("An issue without a number renders the New title branch")
    func newTitleBranch() {
        #expect(Issue(number: nil, title: "Site walk").rowTitle == "New  -  Site walk")
        #expect(Issue(number: 0, title: "Site walk").rowTitle == "New  -  Site walk")
        #expect(Issue(number: 928, title: "Commissioning").rowTitle == "#928  -  Commissioning")
    }

    @Test("Mutations through the shared key are visible to every reader")
    func sharedKeyRoundTrips() {
        withDependencies {
            $0.defaultFileStorage = .inMemory
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            $issues.withLock { $0[0].title = "Persisted" }

            @Shared(.issues) var reloaded
            #expect(reloaded[0].title == "Persisted")
        }
    }
}
