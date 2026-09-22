import SwiftUI

/// A form row that picks one value from a menu, drawing the chosen value
/// itself: a small icon, a regular gap, then the word, in the tint. A plain
/// menu `Picker` renders its current value at the size of the menu item, the
/// icon too big and pressed against its label — this keeps both in step with
/// the text around them.
struct MenuPickerRow<Value: Hashable>: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    var image: (Value) -> Image? = { _ in nil }

    var body: some View {
        Label {
            LabeledContent(title) {
                Menu {
                    Picker(selection: $selection) {
                        ForEach(options, id: \.self) { option in
                            if let image = image(option) {
                                Label { Text(label(option)) } icon: { image }
                                    .tag(option)
                            } else {
                                Text(label(option)).tag(option)
                            }
                        }
                    } label: {
                        Text(title)
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 8) {
                        if let image = image(selection) {
                            image
                                .font(.subheadline)
                                .imageScale(.small)
                        }
                        Text(label(selection))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    @Previewable @State var genre: BookGenre? = .fantasy
    Form {
        MenuPickerRow(
            title: "Genre",
            icon: "theatermasks",
            selection: $genre,
            options: [nil] + BookGenre.alphabetical.map(Optional.some),
            label: { $0?.label ?? String(localized: "Non renseigné") },
            image: { $0?.image }
        )
    }
    .labelStyle(.row)
}
