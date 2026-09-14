import SwiftUI

/// The reading note, edited in a sheet rather than inline. A note is written in
/// one sitting and can run long, so it gets the whole screen and an explicit
/// save — an inline field that commits on every keystroke would fight the reader
/// mid-sentence.
struct NoteEditorView: View {
    @State private var text: String
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    init(note: String, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        _text = State(initialValue: note)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .padding(.horizontal, 12)
                .navigationTitle("Mon commentaire")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        // An emptied note is a deletion, not an empty string to
                        // store and later render as a blank block.
                        Button("Enregistrer") { onSave(trimmed.isEmpty ? nil : trimmed) }
                            .accessibilityIdentifier("note-save")
                    }
                }
                .onAppear { focused = true }
        }
    }
}

#Preview {
    NoteEditorView(note: "La meilleure prose de fantasy que j'aie lue.", onSave: { _ in }, onCancel: {})
}
