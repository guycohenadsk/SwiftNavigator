import AppRoutes
import SwiftUI

/// The navigation POC, compressed into three lines that sit between the navigation bar and the
/// screen's real content: push to any route, present any route, and push Screen C with a context
/// payload that reports back.
///
/// Chips are generated from `Route.allCases`, which is what keeps the "any screen reaches any
/// screen" claim hand-testable — adding a route to the catalog adds chips here with no edit.
struct NavigationDemoStrip: View {
    var pushRoutes: [Route] = Route.allCases
    var onPush: (Route) -> Void
    var onPresent: ((Route) -> Void)?
    var onPushScreenCWithContext: (() -> Void)?
    var screenCText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            line("Push") {
                ForEach(pushRoutes, id: \.self) { route in
                    chip(route.title) { onPush(route) }
                }
            }

            if let onPresent {
                line("Present") {
                    ForEach(Route.allCases, id: \.self) { route in
                        chip(route.title) { onPresent(route) }
                    }
                }
            }

            if let onPushScreenCWithContext {
                line("Context") {
                    chip(
                        screenCText.map { "Screen C said “\($0)”" } ?? "Push Screen C with context",
                        isHighlighted: screenCText != nil,
                        action: onPushScreenCWithContext
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func line(
        _ label: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            ScrollView(.horizontal) {
                HStack(spacing: 6) { content() }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(
        _ title: String,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isHighlighted ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemBackground))
                .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
