import Foundation

/// The lifecycle states of an RFI (request for information).
public enum RFIStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case draft
    case open
    case answered
    case closed

    public var displayName: String {
        switch self {
        case .draft: "Draft"
        case .open: "Open"
        case .answered: "Answered"
        case .closed: "Closed"
        }
    }
}

/// One RFI, as both the list and the detail screen see it.
public struct RFIItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// `nil` on a freshly created RFI: the row then reads "New  -  …".
    public var number: Int?
    public var subject: String
    public var status: RFIStatus
    public var assigneeName: String?
    public var question: String
    public var dueDate: Date?
    public var createdBy: String
    public var createdByEmail: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        number: Int? = nil,
        subject: String = "",
        status: RFIStatus = .draft,
        assigneeName: String? = nil,
        question: String = "",
        dueDate: Date? = nil,
        createdBy: String = "Guy Cohen",
        createdByEmail: String = "guy.cohen@autodesk.com",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.number = number
        self.subject = subject
        self.status = status
        self.assigneeName = assigneeName
        self.question = question
        self.dueDate = dueDate
        self.createdBy = createdBy
        self.createdByEmail = createdByEmail
        self.createdAt = createdAt
    }

    /// `"RFI-012  -  Subject"`, or `"New  -  Subject"` before the RFI gets a number; `"Untitled"`
    /// stands in for an empty subject.
    public var rowTitle: String {
        let label = if let number, number != 0 { String(format: "RFI-%03d", number) } else { "New" }
        return "\(label)  -  \(subject.isEmpty ? "Untitled" : subject)"
    }
}

// Fixed lists so the pickers have something to offer.
extension RFIItem {
    public static let assigneeOptions = [
        "john.doe@example.com", "dekel.a@example.com", "maya.r@example.com", "sam.okafor@example.com",
    ]
}
