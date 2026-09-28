import SwiftUI

/// The label / value / chevron line every non-text field uses.
struct FieldRowContent: View {
    let label: String
    let value: String?
    var placeholder: String = "None"
    var showsChevron = true

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value ?? placeholder)
                .font(.system(size: 15))
                .foregroundStyle(value == nil ? .tertiary : .primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// A field whose value is chosen from a fixed list. Production reaches a dedicated picker screen
/// here; a menu keeps the interaction honest without inventing four more screens.
struct PickerFieldRow<Option: Hashable>: View {
    let label: String
    let value: Option?
    let options: [Option]
    let title: (Option) -> String
    var allowsClearing = true
    let onSelect: (Option?) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == value {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
            if allowsClearing, value != nil {
                Divider()
                Button("Clear", role: .destructive) { onSelect(nil) }
            }
        } label: {
            FieldRowContent(label: label, value: value.map(title))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("field_\(label)")
    }
}
