import SwiftUI

/// The library list. Pure and previewable: it takes what to draw and what to
/// call, and knows nothing about the network.
///
/// Sections are sagas and shelves of standalone books, tiered by reading
/// status: in progress, then on the pile, then finished. A shelf has no
/// heading: a title over it would name the one thing those books have in
/// common, and "no series" is not a thing.
struct LibraryPage: View {
    let sections: [LibrarySection]
    let isLoading: Bool
    /// The rows are last session's and fresher ones are on their way: a
    /// spinner row leads the list rather than a loader replacing it.
    var isRefreshing: Bool = false
    /// That refresh failed — the leading row becomes a retry.
    var refreshFailed: Bool = false
    let errorMessage: String?
    /// More rows follow the ones on screen: a sentinel closes the list and
    /// asks for them as it appears.
    var hasMore: Bool = false
    var loadMoreFailed: Bool = false
    let onRetry: () async -> Void
    var onRetryRefresh: () async -> Void = {}
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}
    let onAdd: () -> Void
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
                    AsyncButton("Réessayer") { await onRetry() }
                }
            } else if sections.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Bibliothèque")
    }

    private var list: some View {
        List {
            // Leads the rows it is refreshing, never replaces them.
            if isRefreshing || refreshFailed {
                RefreshRow(
                    failed: refreshFailed,
                    loadingLabel: "Mise à jour de la bibliothèque",
                    onRetry: onRetryRefresh
                )
            }
            ForEach(sections) { section in
                if let seriesName = section.seriesName {
                    Section {
                        rows(of: section)
                    } header: {
                        HStack(spacing: 6) {
                            Text(seriesName)
                            // The tag says which of a saga's two shelves this is.
                            // Trailing the name rather than leading it: the name is
                            // what the reader scans for, the language only tells two
                            // headings with that name apart. And only the foreign
                            // shelf gets one: the reader's own language is the default
                            // and drawing it would tag every heading.
                            if let language = section.language, language.isForeign {
                                LanguageTag(language: language)
                            }
                            Spacer(minLength: 8)
                            // The saga's own heart or stars, on the heading's line
                            // and against its right edge, where every row below
                            // keeps its own.
                            OpinionMark(
                                rating: section.opinion?.rating,
                                isFavorite: section.opinion?.favorite == true,
                                font: .caption
                            )
                        }
                    }
                } else {
                    Section {
                        rows(of: section)
                    }
                }
            }
            if hasMore {
                LoadMoreRow(
                    failed: loadMoreFailed,
                    loadingLabel: "Chargement de la suite",
                    onLoadMore: onLoadMore
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await onRetry() }
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
                    // Inside a saga the heading already carries the language:
                    // tagging every row under it would say the same thing
                    // twelve times.
                    language: section.seriesName == nil ? book.language : nil,
                    isFavorite: book.favorite,
                    isHidden: book.hidden
                )
            }
            .tint(.primary)
            // Starts the next page a few rows before the end is reached.
            .onAppear { onPrefetch(book.id) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Bibliothèque vide", systemImage: "books.vertical")
        } description: {
            Text(
                "Scannez la couverture d'un livre, ajoutez-en un à la main, ou importez "
                    + "votre bibliothèque Audible."
            )
        } actions: {
            Button("Ajouter un livre", action: onAdd)
            Button("Importer depuis Audible", action: onImportFromAudible)
        }
    }
}

#Preview("Avec des livres") {
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
            onRetry: {},
            onAdd: {},
            onImportFromAudible: {},
            onBookTapped: { _ in }
        )
    }
}

#Preview("Vide") {
    NavigationStack {
        LibraryPage(
            sections: [],
            isLoading: false,
            errorMessage: nil,
            onRetry: {},
            onAdd: {},
            onImportFromAudible: {},
            onBookTapped: { _ in }
        )
    }
}
