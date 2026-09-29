import SwiftUI

/// A multi-line, editable field that collapses to three lines with a Show more / Show less toggle.
struct ExpandableTextArea: View {
    let label: String
    let text: String
    let isExpanded: Bool
    let onChange: (String) -> Void
    let onToggleExpanded: () -> Void

    private var collapsedLineLimit: Int { 3 }

    /// Rough heuristic — the real component measures the rendered text. Three lines of this width
    /// is around 120 characters.
    private var isTruncatable: Bool {
        text.count > 120 || text.contains("\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "None",
                text: Binding(get: { text }, set: onChange),
                axis: .vertical
            )
            .font(.system(size: 15))
            .lineLimit(isExpanded ? nil : collapsedLineLimit)
            .accessibilityIdentifier("field_\(label)")

            if isTruncatable {
                Button(isExpanded ? "Show less" : "Show more", action: onToggleExpanded)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 12)
    }
}
