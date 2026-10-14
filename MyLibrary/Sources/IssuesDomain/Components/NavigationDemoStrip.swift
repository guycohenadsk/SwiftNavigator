import SwiftUI

/// The cross-module navigation demo, compressed into a few labeled lines of chips between the
/// navigation bar and the screen's real content. Every chip is written out by the screen that shows
/// it — exactly how a real feature would call another one.
struct NavigationDemoStrip: View {
    struct Line: Identifiable {
        let label: String
        let links: [Link]
        var id: String { label }
    }

    struct Link: Identifiable {
        let id = UUID()
        let title: String
        var isHighlighted = false
        let action: () -> Void

        init(_ title: String, isHighlighted: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.isHighlighted = isHighlighted
            self.action = action
        }
    }

    let lines: [Line]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines) { line in
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .leading)

                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(line.links) { chip($0) }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func chip(_ link: Link) -> some View {
        Button(action: link.action) {
            Text(link.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(link.isHighlighted ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemBackground))
                .foregroundStyle(link.isHighlighted ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
