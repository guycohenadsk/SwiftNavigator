import SwiftUI

/// The lifecycle states an issue can be in. The pin colors come straight from the ACC issue-row
/// spec's `colorV2` table — hardcoded here as hex because this POC has no design-system package
/// to resolve `Alloy.ColorSet` names against.
public enum IssueStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case draft
    case open
    case pending
    case inProgress
    case review
    case completed
    case closed
    case notApproved
    case inDispute

    public var title: String {
        switch self {
        case .draft: "Draft"
        case .open: "Open"
        case .pending: "Pending"
        case .inProgress: "In Progress"
        case .review: "In Review"
        case .completed: "Completed"
        case .closed: "Closed"
        case .notApproved: "Not Approved"
        case .inDispute: "In Dispute"
        }
    }

    /// Fill color of the 40×40 pin circle.
    public var pinColor: Color {
        switch self {
        case .draft: .hex(0x3C3C3C)      // charcoal900
        case .open: .hex(0xFAA21B)       // yellowOrange500
        case .pending: .hex(0x0696D7)    // blue500
        case .inProgress: .hex(0xA3BCDC) // darkBlue300
        case .review: .hex(0xA76EF5)     // purple500
        case .completed: .hex(0xB7D78C)  // green300
        case .closed: .hex(0xDCDCDC)     // charcoal200
        case .notApproved, .inDispute: .hex(0xEC4A41) // red500
        }
    }

    /// Only the two light fills get dark text — the spec states this as a rule, not a per-case
    /// table, so it stays a rule here.
    public var pinTextColor: Color {
        switch self {
        case .open, .closed: .hex(0x3C3C3C)
        default: .white
        }
    }
}

extension Color {
    static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
