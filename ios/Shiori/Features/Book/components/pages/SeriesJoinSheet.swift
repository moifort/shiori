import SwiftUI

/// Filing a standalone book into a saga, from the call to action on its sheet:
/// the saga's name, with the reader's own sagas proposed, and the volume. Short
/// on purpose, like the genre sheet — the reader tapped "add to a series", not
/// "edit everything".
///
/// The saga is named, never keyed, as in the edit form: the server files the
/// book under the saga the reader already holds by that name, or keys a new one
/// on the book's first author.
struct SeriesJoinSheet: View {
    let book: Book
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (BookCorrection) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var volume = ""
    @State private var suggestions: [String] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nom")
                            SeriesNameField(text: $name, suggestions: suggestions)
                        }
                    } icon: {
                        Image(systemName: "books.vertical").foregroundStyle(.secondary)
                    }
                    if !trimmed(name).isEmpty {
                        Label {
                            LabeledContent("Tome") {
                                TextField("Sans numéro", text: $volume)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityIdentifier("edit-series-volume")
                            }
                        } icon: {
                            Image(systemName: "number").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if let problem {
                        Text(problem).foregroundStyle(.red)
                    } else {
                        Text("Choisissez une série de votre bibliothèque pour y ranger ce livre avec les autres tomes, ou nommez-en une nouvelle.")
                    }
                }
            }
            .labelStyle(.row)
            .navigationTitle("Série")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") { await save() }
                        .disabled(trimmed(name).isEmpty || problem != nil || isSaving)
                        .accessibilityIdentifier("series-join-save")
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
            // The proposals are a convenience: a failed read leaves the field
            // plain rather than the sheet unusable.
            .task { suggestions = (try? await BookAPI.vocabulary())?.sagas ?? [] }
        }
        .presentationDetents([.medium, .large])
    }

    /// What the server would refuse, said before the round trip: a volume out
    /// of range, or a new saga it could not key — a saga is keyed on its first
    /// author, and only one the reader already holds can be joined without one.
    private var problem: String? {
        guard !trimmed(name).isEmpty else { return nil }
        if !trimmed(volume).isEmpty, !(1...200).contains(Int(trimmed(volume)) ?? 0) {
            return String(localized: "Le tome doit être un nombre entre 1 et 200.")
        }
        let held = suggestions.contains { $0.localizedCaseInsensitiveCompare(trimmed(name)) == .orderedSame }
        if book.authors.isEmpty, !held {
            return String(localized: "Ajoutez un auteur pour créer une nouvelle série.")
        }
        return nil
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var correction = BookCorrection()
        correction.series = .set(SeriesPlacement(name: trimmed(name), volume: Int(trimmed(volume))))
        if let failure = await onSave(correction) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    SeriesJoinSheet(
        book: Book(id: "1", title: "Gataca", authors: ["Franck Thilliez"], status: .read),
        onSave: { _ in nil }
    )
}
