import SwiftUI

/// A date field that expands an inline graphical picker underneath itself, rather than pushing a
/// picker screen.
struct DatePickerField: View {
    let label: String
    let date: Date?
    let isExpanded: Bool
    let onTap: () -> Void
    let onChange: (Date?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                FieldRowContent(
                    label: label,
                    value: date.map { $0.formatted(date: .abbreviated, time: .omitted) },
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("field_\(label)")

            if isExpanded {
                DatePicker(
                    label,
                    selection: Binding(get: { date ?? Date() }, set: { onChange($0) }),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                if date != nil {
                    Button("Clear", role: .destructive) { onChange(nil) }
                        .font(.caption.weight(.semibold))
                        .padding(.bottom, 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
