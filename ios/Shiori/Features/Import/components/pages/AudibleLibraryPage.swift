import SwiftUI

/// The Audible library, to tick through. Pure and previewable: it takes what to
/// draw and what to call, and knows nothing about the network.
///
/// Titles already catalogued stay in the list, shown ticked off and untappable.
/// Hiding them would read as "the import lost some"; showing them as missing
/// would invite a reader to import a duplicate the server would refuse anyway.
struct AudibleLibraryPage: View {
    let books: [ImportableBook]
    let isLoading: Bool
    let isImporting: Bool
    let selectedCount: Int
    let canImport: Bool
    let isSelected: (ImportableBook) -> Bool
    let onToggle: (ImportableBook) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onImport: () -> Void
    let isAutoSyncOn: Bool
    let onAutoSyncChange: (Bool) -> Void
    let onDisconnect: () -> Void

    var body: some View {
        Group {
            if isLoading && books.isEmpty {
                LoadingStateView(label: "Lecture de votre bibliothèque Audible...")
            } else if books.isEmpty {
                ContentUnavailableView {
                    Label("Bibliothèque vide", systemImage: "headphones")
                } description: {
                    Text(
                        "Aucun livre audio sur ce compte. Vérifiez la boutique choisie : une "
                            + "bibliothèque française ne s'ouvre pas depuis audible.com."
                    )
                } actions: {
                    Button("Changer de compte", action: onDisconnect)
                }
            } else {
                list
            }
        }
        .navigationTitle("Audible")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tout sélectionner", action: onSelectAll)
                    Button("Tout désélectionner", action: onDeselectAll)
                    Divider()
                    Button("Déconnecter Audible", role: .destructive, action: onDisconnect)
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("audible-options")
            }
        }
        .safeAreaInset(edge: .bottom) { importBar }
    }

    /// The one setting on this screen, above the list rather than buried in the
    /// options menu: it writes books into the library without asking again, so it
    /// is stated where the reader can read what it does.
    private var syncSection: some View {
        Section {
            Toggle(
                "Synchroniser chaque nuit",
                isOn: Binding(get: { isAutoSyncOn }, set: onAutoSyncChange)
            )
            .accessibilityIdentifier("audible-auto-sync")
        } footer: {
            Text(
                "Chaque nuit, les livres audio achetés depuis la veille rejoignent votre "
                    + "bibliothèque, et ceux que vous avez terminés sur Audible sont marqués "
                    + "comme lus. Vos notes et vos commentaires ne sont jamais modifiés."
            )
        }
    }

    private var list: some View {
        List {
            syncSection
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

    private func row(_ book: ImportableBook) -> some View {
        HStack(spacing: 12) {
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

    private func tickSymbol(for book: ImportableBook) -> String {
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
            .accessibilityIdentifier("audible-import")

            if isImporting {
                // A whole library is one request: it can take a minute, and a
                // silent button reads as a frozen screen.
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
        AudibleLibraryPage(
            books: [
                ImportableBook(
                    asin: "B002V1OF70",
                    title: "Le Nom du vent",
                    authors: ["Patrick Rothfuss"],
                    narrators: ["Bernard Gabay"],
                    durationMinutes: 1770,
                    coverURL: nil,
                    seriesName: "Chronique du tueur de roi",
                    volume: 1,
                    status: .read,
                    finishedAt: nil,
                    alreadyInLibrary: false
                ),
                ImportableBook(
                    asin: "B00X57B4KE",
                    title: "La Peur du sage",
                    authors: ["Patrick Rothfuss"],
                    narrators: ["Bernard Gabay"],
                    durationMinutes: 2460,
                    coverURL: nil,
                    seriesName: "Chronique du tueur de roi",
                    volume: 2,
                    status: .toRead,
                    finishedAt: nil,
                    alreadyInLibrary: true
                ),
            ],
            isLoading: false,
            isImporting: false,
            selectedCount: 1,
            canImport: true,
            isSelected: { _ in true },
            onToggle: { _ in },
            onSelectAll: {},
            onDeselectAll: {},
            onImport: {},
            isAutoSyncOn: true,
            onAutoSyncChange: { _ in },
            onDisconnect: {}
        )
    }
}
