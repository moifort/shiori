import SwiftUI

/// A form row that picks one value from a menu, drawing the chosen value
/// itself: a small icon, a regular gap, then the word, in the tint. A plain
/// menu `Picker` renders its current value at the size of the menu item, the
/// icon too big and pressed against its label — this keeps both in step with
/// the text around them. The options in the menu keep their full icons.
///
/// The row's label is the caller's: a system `Label` on a Vinarium-style form,
/// a grey-iconed one under `.labelStyle(.row)`, or a bare word.
struct MenuPicker<Value: Hashable, RowLabel: View>: View {
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    let image: (Value) -> Image?
    let rowLabel: RowLabel

    init(
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String,
        image: @escaping (Value) -> Image? = { _ in nil },
        @ViewBuilder rowLabel: () -> RowLabel
    ) {
        _selection = selection
        self.options = options
        self.label = label
        self.image = image
        self.rowLabel = rowLabel()
    }

    var body: some View {
        LabeledContent {
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
                    EmptyView()
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 6) {
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
        } label: {
            rowLabel
        }
    }
}

extension MenuPicker where RowLabel == Label<Text, Image> {
    /// The row as Vinarium's edit form draws one: a system icon and a title.
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String,
        image: @escaping (Value) -> Image? = { _ in nil }
    ) {
        self.init(selection: selection, options: options, label: label, image: image) {
            Label(title, systemImage: systemImage)
        }
    }
}

extension MenuPicker where RowLabel == Text {
    /// The row with a bare title, for a form whose rows carry no icon.
    init(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String,
        image: @escaping (Value) -> Image? = { _ in nil }
    ) {
        self.init(selection: selection, options: options, label: label, image: image) {
            Text(title)
        }
    }
}

#Preview {
    @Previewable @State var genre: BookGenre? = .fantasy
    @Previewable @State var format: BookFormat = .audiobook
    Form {
        MenuPicker(
            "Genre",
            systemImage: "theatermasks",
            selection: $genre,
            options: [nil] + BookGenre.alphabetical.map(Optional.some),
            label: { $0?.label ?? String(localized: "Non renseigné") },
            image: { $0?.image }
        )
        MenuPicker(
            "Format",
            selection: $format,
            options: BookFormat.allCases,
            label: { $0.label },
            image: { Image(systemName: $0.symbol) }
        )
    }
}
