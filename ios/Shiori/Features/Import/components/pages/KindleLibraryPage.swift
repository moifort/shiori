import SwiftUI

/// The Kindle library, to tick through. Pure and previewable: it takes what to
/// draw and what to call, and knows nothing about the network.
///
/// Titles already catalogued stay in the list, ticked off and untappable:
/// hidden, they would read as books the import lost.
struct KindleLibraryPage: View {
    let books: [ImportableKindleBook]
    let isLoading: Bool
    let isImporting: Bool
    let selectedCount: Int
    let canImport: Bool
    let isSelected: (ImportableKindleBook) -> Bool
    let onToggle: (ImportableKindleBook) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onImport: () -> Void

    var body: some View {
        Group {
            if isLoading && books.isEmpty {
                ProgressView("Lecture de votre bibliothèque Kindle...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if books.isEmpty {
                EmptyStateView(
                    systemImage: "book.closed",
                    title: "Bibliothèque vide",
                    message: "Aucun livre Kindle sur ce compte."
                )
            } else {
                list
            }
        }
        .navigationTitle("Choisir des livres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tout sélectionner", action: onSelectAll)
                    Button("Tout désélectionner", action: onDeselectAll)
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("kindle-options")
            }
        }
        .safeAreaInset(edge: .bottom) { importBar }
    }

    private var list: some View {
        List {
            ForEach(books) { book in
                Button {
                    onToggle(book)
                } label: {
                    row(book)
                }
                .tint(.primary)
                .disabled(book.alreadyInLibrary)
            }
        }
        .listStyle(.plain)
    }

    private func row(_ book: ImportableKindleBook) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tickSymbol(for: book))
                .font(.title3)
                .foregroundStyle(book.alreadyInLibrary ? Color.secondary : Color.accentColor)
                .accessibilityHidden(true)
            BookCover(book: book.asCoverSubject, width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(book.authorLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !book.detailLine.isEmpty {
                    Text(book.detailLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if book.alreadyInLibrary {
                Text("Déjà présent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if book.status != .toRead {
                Image(systemName: book.status.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(book.status.label)
            }
        }
        .padding(.vertical, 2)
        .opacity(book.alreadyInLibrary ? 0.55 : 1)
    }

    private func tickSymbol(for book: ImportableKindleBook) -> String {
        if book.alreadyInLibrary { return "checkmark.circle" }
        return isSelected(book) ? "checkmark.circle.fill" : "circle"
    }

    private var importBar: some View {
        VStack(spacing: 8) {
            Button(action: onImport) {
                HStack {
                    Spacer()
                    if isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Text(importLabel)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canImport)
            .accessibilityIdentifier("kindle-import")

            if isImporting {
                Text("Import en cours, gardez l'écran ouvert...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.bar)
    }

    private var importLabel: String {
        selectedCount == 0
            ? String(localized: "Sélectionnez des livres")
            : String(localized: "Importer \(selectedCount) livre(s)")
    }
}

#Preview {
    NavigationStack {
        KindleLibraryPage(
            books: ImportableKindleBook.previews,
            isLoading: false,
            isImporting: false,
            selectedCount: 3,
            canImport: true,
            isSelected: { !$0.alreadyInLibrary },
            onToggle: { _ in },
            onSelectAll: {},
            onDeselectAll: {},
            onImport: {}
        )
    }
}
