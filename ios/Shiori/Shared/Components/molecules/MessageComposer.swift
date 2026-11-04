import SwiftUI

/// The field Messages docks over the keyboard: a round cancel beside a
/// capsule that grows with the text, the blue arrow inside it. Filled with
/// what is there, so the reader corrects rather than retypes.
///
/// The arrow stays grey while nothing changed. An emptied field is sent as
/// nil: what was written is taken back.
struct MessageComposer: View {
    let current: String?
    var placeholder: LocalizedStringKey = "Commentaire"
    /// The longest text accepted; past it the arrow stays grey.
    var maxLength = Int.max
    let onCancel: () -> Void
    let onSend: (String?) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        current: String?,
        placeholder: LocalizedStringKey = "Commentaire",
        maxLength: Int = .max,
        onCancel: @escaping () -> Void,
        onSend: @escaping (String?) -> Void
    ) {
        self.current = current
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.onCancel = onCancel
        self.onSend = onSend
        _text = State(initialValue: current ?? "")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Annuler")
            .accessibilityIdentifier("composer-cancel")

            HStack(alignment: .bottom, spacing: 6) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(.vertical, 7)
                    .accessibilityIdentifier("composer-text")
                Button { onSend(edited) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, canSend ? Color(.systemBlue) : Color(.systemGray3))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Enregistrer")
                .accessibilityIdentifier("composer-send")
                .padding(.bottom, 3)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .background(Color(.systemBackground).opacity(0.9), in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { isFocused = true }
    }

    /// What the field says now. Nil when only blanks are left.
    private var edited: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var canSend: Bool {
        edited != current && (edited?.count ?? 0) <= maxLength
    }
}

#Preview("Existing") {
    VStack {
        Spacer()
        MessageComposer(current: "La scène de l'auberge, au début, vaut le livre entier.", onCancel: {}, onSend: { _ in })
    }
}

#Preview("New") {
    VStack {
        Spacer()
        MessageComposer(current: nil, onCancel: {}, onSend: { _ in })
    }
}
