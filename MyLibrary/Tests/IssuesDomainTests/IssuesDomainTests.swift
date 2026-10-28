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
