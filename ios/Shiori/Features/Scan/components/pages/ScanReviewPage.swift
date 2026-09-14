import SwiftUI

/// What the model proposed, before anything is saved. Every field is editable
/// because every field is a guess — the safety net against a misread cover.
///
/// The series is shown but not editable. Membership is resolved server-side and
/// keyed to a shared catalogue; letting the reader retype it here would create a
/// saga no catalogue knows, which would then never gather its other volumes.
struct ScanReviewPage: View {
    @State private var draft: BookDraft
    @State private var authorLine: String
    let seriesLabel: String?
    let isSaving: Bool
    let onSave: (BookDraft) -> Void
    let onRetake: () -> Void

    init(
        draft: BookDraft,
        seriesLabel: String?,
        isSaving: Bool,
        onSave: @escaping (BookDraft) -> Void,
        onRetake: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        _authorLine = State(initialValue: draft.authors.joined(separator: ", "))
        self.seriesLabel = seriesLabel
        self.isSaving = isSaving
        self.onSave = onSave
        self.onRetake = onRetake
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Titre", text: $draft.title)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("review-title")
                TextField("Auteur", text: $authorLine)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("review-author")
            } header: {
                Text("À vérifier")
            } footer: {
                Text("Ces informations viennent d'une lecture automatique de la couverture. Corrigez ce qui est faux avant d'enregistrer.")
            }

            if let seriesLabel {
                Section("Série") {
                    Label(seriesLabel, systemImage: "square.stack")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lecture") {
                Picker("Statut", selection: $draft.status) {
                    ForEach(ReadingStatus.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if let synopsis = draft.synopsis {
                Section("Résumé") {
                    Text(synopsis).font(.callout)
                }
            }

            Section("Informations trouvées") {
                if let publisher = draft.publisher {
                    LabeledContent("Éditeur", value: publisher)
                }
                if let year = draft.firstPublishedIn {
                    LabeledContent("Première parution", value: String(year))
                }
                if let pages = draft.pageCount {
                    LabeledContent("Pages", value: String(pages))
                }
                if !draft.genres.isEmpty {
                    LabeledContent("Genres", value: draft.genres.joined(separator: ", "))
                }
                if let isbn = draft.isbn13 {
                    LabeledContent("ISBN", value: isbn).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Vérifier")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .disabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reprendre", action: onRetake)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    var approved = draft
                    approved.authors = authorLine
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    onSave(approved)
                }
                .disabled(trimmedTitle.isEmpty || isSaving)
                .accessibilityIdentifier("review-save")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScanReviewPage(
            draft: BookDraft(
                title: "Le Nom du vent",
                authors: ["Patrick Rothfuss"],
                publisher: "Bragelonne",
                firstPublishedIn: 2007,
                synopsis: "Kvothe raconte sa propre légende.",
                genres: ["Fantasy"],
                pageCount: 662,
                isbn13: "9782352943556"
            ),
            seriesLabel: "Chronique du tueur de roi · Tome 1",
            isSaving: false,
            onSave: { _ in },
            onRetake: {}
        )
    }
}
