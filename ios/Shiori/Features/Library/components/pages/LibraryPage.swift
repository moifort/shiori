import SwiftUI

/// The library list. Pure and previewable: it takes what to draw and what to
/// call, and knows nothing about the network.
///
/// Sections are sagas, trailed by a titled shelf of standalone books. The title
/// says what they share — no series — so the shelf does not read as leftovers
/// tacked onto the last saga.
struct LibraryPage: View {
    let sections: [LibrarySection]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var filter: ReadingStatus?
    let onRetry: () -> Void
    let onAddManually: () -> Void
    let onImportFromAudible: () -> Void
    let onBookTapped: (Book) -> Void

    var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                ProgressView("Chargement de votre bibliothèque...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, sections.isEmpty {
                ContentUnavailableView {
                    Label("Bibliothèque indisponible", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Réessayer", action: onRetry)
                }
            } else if sections.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Bibliothèque")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filtrer", selection: $filter) {
                        Text("Tout").tag(ReadingStatus?.none)
                        ForEach(ReadingStatus.allCases) { status in
                            Label(status.label, systemImage: status.symbol)
                                .tag(ReadingStatus?.some(status))
                        }
                    }
                } label: {
                    Label("Filtrer", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityIdentifier("library-filter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // A menu rather than a button: a book now arrives three ways —
                // scanned from the tab bar, typed in, or imported from Audible —
                // and only the scan deserves a permanent place of its own.
                Menu {
                    Button {
                        onAddManually()
                    } label: {
                        Label("Ajouter à la main", systemImage: "square.and.pencil")
                    }
                    Button {
                        onImportFromAudible()
                    } label: {
                        Label("Importer depuis Audible", systemImage: "headphones")
                    }
                } label: {
                    Label("Ajouter un livre", systemImage: "plus")
                }
                .accessibilityIdentifier("library-add")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section {
                    rows(of: section)
                } header: {
                    HStack(spacing: 6) {
                        Text(section.seriesName ?? String(localized: "Livres indépendants"))
                        // The flag says which of a saga's two shelves this is.
                        // Trailing the name rather than leading it: the name is
                        // what the reader scans for, the language only tells two
                        // headings with that name apart.
                        if let language = section.language {
                            Text(language.flag).accessibilityLabel(Text(language.label))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onRetry() }
    }

    private func rows(of section: LibrarySection) -> some View {
        // A Button rather than a NavigationLink: the book opens as a sheet over
        // the list, so the row carries no disclosure chevron promising a push.
        ForEach(section.books) { book in
            Button {
                onBookTapped(book)
            } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.rating,
                    // Only inside a saga: on the standalone shelf there is no
                    // numbering for a label to explain.
                    volumeLabel: section.seriesName != nil ? book.series?.label : nil,
                    genre: book.genre,
                    subgenre: book.subgenres.first,
                    format: book.format,
                    language: book.language,
                    isFavorite: book.favorite,
                    isHidden: book.hidden
                )
            }
            .tint(.primary)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            ContentUnavailableView {
                Label("Rien ici", systemImage: filter.symbol)
            } description: {
                Text("Aucun livre au statut « \(filter.label) ».")
            } actions: {
                Button("Voir toute la bibliothèque") { self.filter = nil }
            }
        } else {
            ContentUnavailableView {
                Label("Bibliothèque vide", systemImage: "books.vertical")
            } description: {
                Text(
                    "Scannez la couverture d'un livre, ajoutez-en un à la main, ou importez "
                        + "votre bibliothèque Audible."
                )
            } actions: {
                Button("Ajouter à la main", action: onAddManually)
                Button("Importer depuis Audible", action: onImportFromAudible)
            }
        }
    }
}

#Preview("Avec des livres") {
    @Previewable @State var filter: ReadingStatus?
    let saga = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main)
    let saga2 = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 2, kind: .main)

    return NavigationStack {
        LibraryPage(
            sections: [
                LibrarySection(
                    seriesId: "s1",
                    seriesName: "Chronique du tueur de roi",
                    books: [
                        Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], series: saga, status: .read, rating: 5),
                        Book(id: "2", title: "La Peur du sage", authors: ["Patrick Rothfuss"], series: saga2, status: .reading),
                    ]
                ),
                LibrarySection(
                    seriesId: nil,
                    seriesName: nil,
                    books: [
                        Book(id: "3", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead, hidden: true),
                    ]
                ),
            ],
            isLoading: false,
            errorMessage: nil,
            filter: $filter,
            onRetry: {},
            onAddManually: {},
            onImportFromAudible: {},
            onBookTapped: { _ in }
        )
    }
}

#Preview("Vide") {
    @Previewable @State var filter: ReadingStatus?
    NavigationStack {
        LibraryPage(
            sections: [],
            isLoading: false,
            errorMessage: nil,
            filter: $filter,
            onRetry: {},
            onAddManually: {},
            onImportFromAudible: {},
            onBookTapped: { _ in }
        )
    }
}
