import Foundation
import IdentifiedCollections

extension RFIItem {
    /// First-launch data. Dates and ids are fixed so the seed is the same on every launch.
    public static let seed: IdentifiedArrayOf<RFIItem> = [
        make(1, 12, "Slab thickness at grid C-4", .open, "maya.r@example.com", "Confirm the slab thickness against the revised structural set.", due: 1_791_000_000),
        make(2, 13, "Fire rating of corridor doors", .answered, "john.doe@example.com", "Which rating applies to the level 2 corridor doors?", due: 1_791_500_000),
        make(3, 14, "Duct clash above ceiling, level 3", .open, "sam.okafor@example.com", "The main duct clashes with the sprinkler line.", due: 1_792_000_000),
        make(4, 15, "Curtain wall anchor spacing", .draft, nil, "", due: nil),
        make(5, 16, "Roof drain location", .closed, "dekel.a@example.com", "Drain position differs between architectural and plumbing sheets.", due: 1_790_500_000),
        make(6, 17, "Elevator pit waterproofing", .open, nil, "Is a membrane required below the pit slab?", due: 1_793_000_000),
    ]

    private static func make(
        _ index: Int,
        _ number: Int,
        _ subject: String,
        _ status: RFIStatus,
        _ assignee: String?,
        _ question: String,
        due: TimeInterval?
    ) -> RFIItem {
        RFIItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 9000 + index))!,
            number: number,
            subject: subject,
            status: status,
            assigneeName: assignee,
            question: question,
            dueDate: due.map { Date(timeIntervalSince1970: $0) },
            createdAt: Date(timeIntervalSince1970: 1_789_000_000 + Double(index) * 3_600)
        )
    }
}
