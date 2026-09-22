import SwiftUI

/// Changing what a book is about, from its genre row: the genre from the closed
/// list, the subgenres as free words. Short on purpose — the reader tapped a
/// genre, not "edit everything" — and the correction lands on every volume of
/// the saga at once, which the footer says before they confirm.
struct GenreEditSheet: View {
    let book: Book
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (BookCorrection) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var genre: BookGenre?
    @State private var subgenres: String
    @State private var suggestions: [String] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(book: Book, onSave: @escaping (BookCorrection) async -> String?) {
        self.book = book
        self.onSave = onSave
        _genre = State(initialValue: book.genre)
        _subgenres = State(initialValue: book.subgenres.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MenuPicker(
                        selection: $genre,
                        options: [nil] + BookGenre.alphabetical.map(Optional.some),
                        label: { $0?.label ?? String(localized: "Non renseigné") },
                        image: { $0?.image }
                    ) {
                        Label {
                            Text("Genre")
                        } icon: {
                            Image(systemName: "theatermasks").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("edit-genre")
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sous-genres")
                            SubgenreField(text: $subgenres, suggestions: suggestions)
                        }
                    } icon: {
                        Image(systemName: "tag").foregroundStyle(.secondary)
                    }
                } footer: {
                    if book.series != nil {
                        Text("Séparez les sous-genres par des virgules, trois au plus. Le genre décrit la série : il sera appliqué à tous ses tomes de votre bibliothèque.")
                    } else {
                        Text("Séparez les sous-genres par des virgules, trois au plus ; le premier est celui qui s'affiche dans la liste.")
                    }
                }
            }
            .labelStyle(.row)
            .navigationTitle("Genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") { await save() }
                        .disabled(correction.isEmpty || isSaving)
                        .accessibilityIdentifier("genre-save")
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
            // The vocabulary is a convenience: a failed read leaves the field
            // plain rather than the sheet unusable.
            .task { suggestions = (try? await BookAPI.subgenres()) ?? [] }
        }
        .presentationDetents([.medium, .large])
    }

    private var correction: BookCorrection {
        var correction = BookCorrection()
        if genre != book.genre { correction.genre = genre.map { .set($0) } ?? .clear }
        let list = subgenres.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let subgenreList = Array(list.prefix(3))
        if subgenreList != book.subgenres { correction.subgenres = subgenreList }
        return correction
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(correction) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

#Preview {
    GenreEditSheet(
        book: Book(
            id: "1",
            title: "Le Nom du vent",
            authors: ["Patrick Rothfuss"],
            genre: .fantasy,
            subgenres: ["Roman initiatique"],
            series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
            status: .reading
        ),
        onSave: { _ in nil }
    )
}
