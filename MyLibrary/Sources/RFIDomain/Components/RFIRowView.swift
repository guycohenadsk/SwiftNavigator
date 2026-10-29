import SwiftUI

/// One row of the RFI list: title, assignee and status, a chevron, and the row's own divider.
struct RFIRowView: View {
    let rfi: RFIItem
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rfi.rowTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .accessibilityIdentifier(rfi.rowTitle)
                    Text("\(rfi.status.displayName)  ·  \(rfi.assigneeName ?? "Unassigned")")
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
        .accessibilityIdentifier("single_rfi_view_\(index)")
    }
}
