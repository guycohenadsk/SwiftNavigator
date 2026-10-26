import Foundation

/// One issue, as both the list and the detail screen see it.
///
/// Production splits this into a light list model and a details model because they come from
/// different SQL joins. Here there is one JSON file, so one struct — the detail screen simply
/// renders more of it.
public struct Issue: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// `nil` on a freshly created issue — the row then reads "New - …" instead of "#928 - …".
    public var number: Int?
    public var title: String
    public var status: IssueStatus
    /// The issue *type*'s abbreviation shown inside the pin ("CM", "PL"). Not derived from status.
    public var typeCode: String?
    public var assigneeName: String?
    public var issueDescription: String
    public var location: String?
    public var locationDetails: String?
    public var dueDate: Date?
    public var startDate: Date?
    public var rootCause: String?
    public var createdBy: String
    public var createdByEmail: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        number: Int? = nil,
        title: String = "",
        status: IssueStatus = .draft,
        typeCode: String? = nil,
        assigneeName: String? = nil,
        issueDescription: String = "",
        location: String? = nil,
        locationDetails: String? = nil,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        rootCause: String? = nil,
        createdBy: String = "Guy Cohen",
        createdByEmail: String = "guy.cohen@autodesk.com",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.status = status
        self.typeCode = typeCode
        self.assigneeName = assigneeName
        self.issueDescription = issueDescription
        self.location = location
        self.locationDetails = locationDetails
        self.dueDate = dueDate
        self.startDate = startDate
        self.rootCause = rootCause
        self.createdBy = createdBy
        self.createdByEmail = createdByEmail
        self.createdAt = createdAt
    }

    /// `"#928  -  Commissioning"`, or `"New  -  …"` before the issue gets a number. The two spaces
    /// either side of the dash are the localized format string's, not a typo.
    public var rowTitle: String {
        let number = if let number, number != 0 { "#\(number)" } else { "New" }
        return "\(number)  -  \(title.isEmpty ? "Untitled" : title)"
    }

    public var maxTitleLength: Int { 100 }
}

// Server-configured in production; fixed lists here so the pickers have something to offer.
extension Issue {
    public static let typeCodeOptions = ["CM", "PL", "EL", "WL", "PT", "FFD"]
    public static let assigneeOptions = [
        "john.doe@example.com", "dekel.a@example.com", "maya.r@example.com", "sam.okafor@example.com",
    ]
    public static let locationOptions = ["Level 1 · East Wing", "Level 2 · Atrium", "Level 3 · Mech Room", "Roof"]
    public static let rootCauseOptions = ["Design", "Coordination", "Installation", "Material", "Weather"]
}
