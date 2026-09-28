import SwiftUI

/// One row of the issues list, built to the geometry in the ACC issue-row spec: 16pt padding on
/// both axes, pin, two-line text column, chevron, and the row's own divider underneath.
struct IssueRowView: View {
    let issue: Issue
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IssuePinView(status: issue.status, typeCode: issue.typeCode)

                VStack(alignment: .leading) {
                    Text(issue.rowTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .accessibilityIdentifier(issue.rowTitle)
                    Text(issue.assigneeName ?? "Unassigned")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())

            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("single_issue_view_\(index)")
    }
}
