import Foundation
import IdentifiedCollections

extension Issue {
    /// First-launch contents of `issues.json`. Deliberately mixed: some issues carry nearly every
    /// field, three are sparse enough to trigger the detail screen's empty-fields grouping, and
    /// one has no number so the "New" title branch renders without creating anything.
    public static let seed: IdentifiedArrayOf<Issue> = [
        Issue(
            id: uid(1), number: 928, title: "Commissioning", status: .open, typeCode: "CM",
            assigneeName: "john.doe@example.com",
            issueDescription: "Air balancing report for AHU-3 is missing sign-off from the mechanical contractor.",
            location: "Level 2 · Atrium", locationDetails: "Above ceiling, grid F7",
            dueDate: day(2026, 10, 14), startDate: day(2026, 9, 21), rootCause: "Coordination",
            createdBy: "Dekel Avrahami", createdByEmail: "dekel.a@example.com", createdAt: day(2026, 9, 18)
        ),
        Issue(
            id: uid(2), number: 931, title: "Plumbing riser leak", status: .inProgress, typeCode: "PL",
            assigneeName: "dekel.a@example.com",
            issueDescription: "Slow drip at the 4\" riser joint; pan installed as a temporary measure.",
            location: "Level 3 · Mech Room", dueDate: day(2026, 10, 2),
            createdBy: "Maya Rosen", createdByEmail: "maya.r@example.com", createdAt: day(2026, 9, 20)
        ),
        Issue(
            id: uid(3), number: 904, title: "Electrical panel labeling", status: .closed, typeCode: "EL",
            assigneeName: "maya.r@example.com",
            issueDescription: "Panel LP-2 circuits relabeled to match the as-built schedule.",
            location: "Level 1 · East Wing", locationDetails: "Electrical closet 1.14",
            dueDate: day(2026, 9, 12), startDate: day(2026, 9, 1), rootCause: "Installation",
            createdBy: "Guy Cohen", createdByEmail: "guy.cohen@autodesk.com", createdAt: day(2026, 8, 28)
        ),
        Issue(
            id: uid(4), number: 942, title: "Wall crack at grid C4", status: .notApproved, typeCode: "WL",
            assigneeName: "sam.okafor@example.com",
            issueDescription: "Hairline crack reappeared after the first patch. Structural review requested.",
            rootCause: "Design",
            createdBy: "Sam Okafor", createdByEmail: "sam.okafor@example.com", createdAt: day(2026, 9, 24)
        ),
        Issue(
            id: uid(5), number: 950, title: "Paint touch-up in lobby", status: .pending, typeCode: "PT",
            createdBy: "Maya Rosen", createdByEmail: "maya.r@example.com", createdAt: day(2026, 9, 25)
        ),
        Issue(
            id: uid(6), number: 955, title: "Fire damper access panel", status: .review, typeCode: "FFD",
            assigneeName: "john.doe@example.com",
            issueDescription: "Access panel is undersized for inspection; confirm replacement size with the AHJ.",
            createdBy: "Dekel Avrahami", createdByEmail: "dekel.a@example.com", createdAt: day(2026, 9, 26)
        ),
        Issue(
            id: uid(7), number: 960, title: "Roof drain blockage", status: .inDispute, typeCode: "PL",
            location: "Roof",
            createdBy: "Guy Cohen", createdByEmail: "guy.cohen@autodesk.com", createdAt: day(2026, 9, 27)
        ),
        Issue(
            id: uid(8), title: "Site walk follow-up", status: .draft,
            createdBy: "Guy Cohen", createdByEmail: "guy.cohen@autodesk.com", createdAt: day(2026, 9, 28)
        ),
    ]

    private static func uid(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day, hour: 9, minute: 30)
            .date ?? Date(timeIntervalSince1970: 0)
    }
}
