import SwiftUI

/// Name a spine the model could not read, or fix one it misread: the crop
/// enlarged, a title and the authors. The rest is looked up when it is added.
struct DetectedBookSheet: View {
    let book: DetectedBook
    let crop: UIImage?
    let onSave: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var authors: String

    init(book: DetectedBook, crop: UIImage?, onSave: @escaping (String, [String]) -> Void) {
        self.book = book
        self.crop = crop
        self.onSave = onSave
        _title = State(initialValue: book.title ?? "")
        _authors = State(initialValue: book.authors.joined(separator: ", "))
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let crop {
                    Section {
                        Image(uiImage: crop)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                    }
                }
                Section("Titre") {
                    TextField("Titre du livre", text: $title)
                        .accessibilityIdentifier("shelf-correct-title")
                }
                Section("Auteurs") {
                    TextField("Séparés par des virgules", text: $authors)
                        .accessibilityIdentifier("shelf-correct-authors")
                }
            }
            .navigationTitle("Corriger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        let names = authors.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(trimmedTitle, names)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier("shelf-correct-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
