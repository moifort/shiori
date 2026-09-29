import SwiftUI

/// What a scan read on the cover — the title, the authors, the format —
/// corrected from a tap on the head of the review page, as a fact is from
/// its row. The authors are typed on one line, separated by commas.
struct ScanIdentitySheet: View {
    let book: Book
    let onSave: (BookCorrection) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var authors: String
    @State private var format: BookFormat

    init(book: Book, onSave: @escaping (BookCorrection) -> Void) {
        self.book = book
        self.onSave = onSave
        _title = State(initialValue: book.title)
        _authors = State(initialValue: book.authors.joined(separator: ", "))
        _format = State(initialValue: book.format)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $title)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("review-title")
                    TextField("Auteur", text: $authors)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("review-author")
                    MenuPicker(
                        "Format",
                        selection: $format,
                        options: BookFormat.allCases,
                        label: { $0.label },
                        image: { Image(systemName: $0.symbol) }
                    )
                    .accessibilityIdentifier("review-format")
                } footer: {
                    Text("Séparez les auteurs par des virgules.")
                }
            }
            .navigationTitle("Titre et auteur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarIconButton(title: "Enregistrer", systemImage: "checkmark") {
                        onSave(correction)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier("review-identity-save")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var correction: BookCorrection {
        var correction = BookCorrection()
        if trimmedTitle != book.title { correction.title = trimmedTitle }
        let list = authors.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if list != book.authors { correction.authors = list }
        if format != book.format { correction.format = format }
        return correction
    }
}
