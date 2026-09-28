import SwiftUI

/// Present in every reference screenshot. The spec flags it as an open question only because the
/// production SwiftUI container hadn't implemented it yet — the data is on the model either way.
struct CreatedByFooter: View {
    let name: String
    let email: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Created by")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(name) on \(date.formatted(date: .abbreviated, time: .omitted)) at \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(email)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
