import SwiftUI

/// The 40×40 status pin. Its *fill* comes from the issue's status; its *label* is the issue
/// type's code — two different things that happen to share one circle.
struct IssuePinView: View {
    let status: IssueStatus
    let typeCode: String?

    var body: some View {
        Circle()
            .fill(status.pinColor)
            .frame(width: 40, height: 40)
            .overlay {
                Text(typeCode ?? "✓")
                    .font(.system(size: 16, weight: .semibold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .foregroundStyle(status.pinTextColor)
            }
    }
}
