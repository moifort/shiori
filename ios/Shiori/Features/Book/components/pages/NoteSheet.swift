import SwiftUI

/// The reader's own comment on a book: free text, private, never shown to a
/// friend. Called "commentaire" on screen because "note" already means the
/// stars. Opened from its row under "Ma lecture", filled with what is there so
/// the reader corrects rather than retypes.
///
/// The server's rules hold before the round trip: a comment emptied is
/// deleted, and one past its length is said rather than sent.
struct NoteSheet: View {
    let current: String?
    /// Answers nil once saved, or the message to show when the save failed.
    /// Nil deletes the comment.
    let onSave: (String?) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    /// The longest `ReadingNote` the server accepts.
    static let maxLength = 10_000

    init(current: String?, onSave: @escaping (String?) async -> String?) {
        self.current = current
        self.onSave = onSave
        _text = State(initialValue: current ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ce que vous en pensez, un passage à retenir…", text: $text, axis: .vertical)
                        .lineLimit(6...)
                        .focused($isFocused)
                        .accessibilityIdentifier("note-text")
                } footer: {
                    if isTooLong {
                        Text("\(edited?.count ?? 0) caractères sur \(Self.maxLength) au plus.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Privé : un ami qui parcourt votre bibliothèque ne le voit jamais.")
                    }
                }

                if current != nil {
                    Section {
                        Button(role: .destructive) {
                            Task { await save(nil) }
                        } label: {
                            Label("Supprimer le commentaire", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .accessibilityIdentifier("note-remove")
                    }
                }
            }
            .navigationTitle("Commentaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {
                        await save(edited)
                    }
                    .disabled(edited == current || isTooLong || isSaving)
                    .accessibilityIdentifier("note-save")
                }
            }
            .disabled(isSaving)
            .alert(
                "Une erreur est survenue",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    /// What the form says now. Nil when only blanks are left: an empty
    /// comment is one taken back.
    private var edited: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isTooLong: Bool {
        (edited?.count ?? 0) > Self.maxLength
    }

    private func save(_ note: String?) async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(note) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

#Preview("New") {
    NoteSheet(current: nil) { _ in nil }
}

#Preview("Existing") {
    NoteSheet(current: "La scène de l'auberge, au début, vaut le livre entier.") { _ in nil }
}
