import SwiftUI

/// "More Issue Details (N Empty)" — the collapsible bucket the contract's field-grouping rules
/// produce.
///
/// The animation lives here, on this view's own root, and the parent must not wrap the toggle in
/// `withAnimation`. That is the spec's animation-isolation rule: a parent animation context leaks
/// into every descendant and makes embedded subtrees re-render mid-frame.
struct EmptyFieldsSection<Content: View>: View {
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text("More Issue Details (\(count) Empty)")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("empty_fields_header")

            if isExpanded {
                content
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
