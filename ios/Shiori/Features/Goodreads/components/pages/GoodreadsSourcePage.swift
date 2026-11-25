import SwiftUI

/// Goodreads in the settings: the last import, a new one, and how to export.
/// There is no connection to keep or cut: Goodreads is a file. Pure and
/// previewable.
struct GoodreadsSourcePage: View {
    /// Nil while it loads, and for a reader who never imported.
    let summary: GoodreadsImportSummary?
    let isLoading: Bool
    var onImport: () -> Void
    var onHowTo: () -> Void

    var body: some View {
        List {
            if let summary {
                Section("Dernier import") {
                    LabeledContent("Importé le", value: summary.importedAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Livres importés", value: summary.imported.formatted())
                    LabeledContent("Déjà chez vous, complétés", value: summary.completed.formatted())
                    if summary.withoutCover > 0 {
                        LabeledContent("Sans couverture", value: summary.withoutCover.formatted())
                    }
                }
                Section {
                    Button("Importer un nouvel export", action: onImport)
                        .accessibilityIdentifier("goodreads-import-again")
                } footer: {
                    Text("Un export plus récent ajoute vos nouveaux livres et met à jour statuts, notes et dates, sans créer de doublon.")
                }
            } else if isLoading {
                HStack {
                    Text("Lecture du dernier import…").foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                }
            } else {
                Section {
                    Button("Importer ma bibliothèque", action: onImport)
                        .accessibilityIdentifier("goodreads-import-first")
                } footer: {
                    Text("Vos étagères, vos notes et vos dates de lecture arrivent depuis le fichier d'export de Goodreads.")
                }
            }
            Section {
                Button(action: onHowTo) {
                    HStack {
                        Text("Comment exporter depuis Goodreads").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Goodreads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Après un import") {
    NavigationStack {
        GoodreadsSourcePage(summary: .preview, isLoading: false, onImport: {}, onHowTo: {})
    }
    .environment(\.colorScheme, .dark)
}

#Preview("Jamais importé") {
    NavigationStack {
        GoodreadsSourcePage(summary: nil, isLoading: false, onImport: {}, onHowTo: {})
    }
    .environment(\.colorScheme, .dark)
}
