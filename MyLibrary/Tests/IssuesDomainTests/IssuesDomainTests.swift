import ComposableArchitecture
import Foundation
import NavigationCore
import NavigatorDependency
import SwiftUI
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
    private func makeListStore(_ navigator: NavigatorSpy = NavigatorSpy()) -> TestStoreOf<IssuesList> {
        withDependencies {
            $0.defaultFileStorage = .inMemory
            $0.uuid = .incrementing
            $0.date = .constant(Self.now)
            $0.navigator = navigator
        } operation: {
            @Shared(.issues) var issues
            $issues.withLock { $0 = Issue.seed }
            return TestStore(initialState: IssuesList.State()) { IssuesList() }
        }
    }

    @Test("Tapping a row pushes that issue's detail request; the list keeps no detail state")
    func tappingRowPushesDetail() async {
        let navigator = NavigatorSpy()
        let store = makeListStore(navigator)
        let issue = store.state.issues[1]

        await store.send(.issueTapped(issue.id))
        await navigator.waitForPushes()
        #expect(navigator.pushed == [Issues.detailRequest(for: issue)])
        #expect(navigator.pushed.first?.intent == .screen(.issues, name: "detail/\(issue.id.uuidString)"))

        navigator.dismissPushed()
        await store.finish()
    }

    @Test("Adding an issue appends it and pushes its detail")
    func addingPushesDetail() async {
        let navigator = NavigatorSpy()
        let store = makeListStore(navigator)
        let new = Issue(id: UUID(0), status: .draft, createdAt: Self.now)

        await store.send(.addIssueTapped) {
            $0.$issues.withLock { $0.append(new) }
        }
        await navigator.waitForPushes()
        #expect(navigator.pushed == [Issues.detailRequest(for: new)])

        navigator.dismissPushed()
        await store.finish()
    }

    @Test("The detail's edits come back as .edited outputs, and the list stores them")
    func editsComeBackAsOutputs() async {
        let navigator = NavigatorSpy()
        let store = makeListStore(navigator)
        let issue = store.state.issues[0]
        await store.send(.issueTapped(issue.id))
        await navigator.waitForPushes()

        var renamed = issue
        renamed.title = "Re-commissioning"
        navigator.reply(IssuesDetail.Output.edited(renamed))
        await store.receive(\.detail.edited) {
            $0.$issues.withLock { $0[id: issue.id]?.title = "Re-commissioning" }
        }

        navigator.dismissPushed()
        await store.finish()
    }

    @Test("A .deleteRequested output removes the issue, and a late edit doesn't bring it back")
    func deleteRequestedRemovesIssue() async {
        let navigator = NavigatorSpy()
        let store = makeListStore(navigator)
        let issue = store.state.issues[2]
        let countBefore = store.state.issues.count
        await store.send(.issueTapped(issue.id))
        await navigator.waitForPushes()

        navigator.reply(IssuesDetail.Output.deleteRequested(issue.id))
        await store.receive(\.detail.deleteRequested) {
            $0.$issues.withLock { $0.remove(id: issue.id) }
        }
        navigator.reply(IssuesDetail.Output.edited(issue))
        await store.receive(\.detail.edited)

        navigator.dismissPushed()
        await store.finish()
        #expect(store.state.issues.count == countBefore - 1)
        #expect(store.state.issues[id: issue.id] == nil)
    }

    @Test("Outputs of another type are not delivered to the list")
    func foreignOutputsSkipped() async {
        let navigator = NavigatorSpy()
        let store = makeListStore(navigator)
        await store.send(.issueTapped(store.state.issues[0].id))
        await navigator.waitForPushes()

        navigator.reply("not an issue output")
        navigator.dismissPushed()
        await store.finish()
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
