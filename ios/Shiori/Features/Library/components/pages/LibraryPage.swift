import SwiftUI

/// The library list. Pure and previewable: it takes what to draw and what to
/// call, and knows nothing about the network.
///
/// Two views, switched from the toolbar as in Vinarium: everything, or the
/// favourites, both sectioned by month as Vinarium's wine list is — newest
/// first, on the day each book was finished, else started, else added — each
/// row carrying its status as a tag. A filter narrows either to one status.
/// Sagas are not gathered here: the Series tab reads a saga whole, and a row
/// names its saga in a tag.
struct LibraryPage: View {
    @Binding var mode: LibraryMode
    @Binding var statusFilter: ReadingStatus?
    let sections: [MonthSection<Book>]
    /// Rows say their own status, unless a filter already says which.
    var showsStatus: Bool = false
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
    let onBookTapped: (Book) -> Void

    /// The shelf is narrowed: an empty list says nothing matches, not that the
    /// library is empty.
    private var isNarrowed: Bool { mode == .favorites || statusFilter != nil }

    var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                ProgressView("Chargement de votre bibliothèque...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, sections.isEmpty {
                EmptyStateView.failure("Bibliothèque indisponible", message: errorMessage, retry: onRetry)
            } else if sections.isEmpty {
                if mode == .favorites {
                    EmptyStateView(
                        systemImage: "heart",
                        title: "Aucun favori",
                        message: "Touchez le cœur d'un livre pour le retrouver ici.",
                        primary: .init("Scanner un livre", systemImage: "camera") { onAdd() }
                    )
                } else if isNarrowed {
                    EmptyStateView(
                        systemImage: statusFilter?.symbol ?? "books.vertical",
                        title: "Aucun livre",
                        message: "Aucun livre de votre bibliothèque n'a ce statut.",
                        primary: .init("Scanner un livre", systemImage: "camera") { onAdd() }
                    )
                } else {
                    emptyState
                }
            } else {
                list
            }
        }
        .navigationTitle("Bibliothèque")
        .navigationSubtitle(mode.subtitle)
        .toolbar {
            ToolbarItemGroup {
                ForEach(LibraryMode.allCases) { item in
                    Button {
                        mode = item
                    } label: {
                        Label(item.label, systemImage: item.icon)
                    }
                    .labelStyle(.iconOnly)
                    .tint(mode == item ? .accentColor : .primary)
                    .accessibilityIdentifier("library-mode-\(item.rawValue)")
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup {
                Menu {
                    Picker("Statut", selection: $statusFilter) {
                        Label("Tous", systemImage: "tray.full").tag(ReadingStatus?.none)
                        // In the order a book lives through them, not the enum's.
                        ForEach([ReadingStatus.reading, .toRead, .read, .dropped]) { status in
                            Label(status.shelfTitle, systemImage: status.symbol)
                                .tag(ReadingStatus?.some(status))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .symbolVariant(statusFilter != nil ? .fill : .none)
                }
                .accessibilityIdentifier("library-filter-menu")
            }
        }
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
                Section(section.title) {
                    rows(of: section)
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

    private func rows(of section: MonthSection<Book>) -> some View {
        // A Button rather than a NavigationLink: the book opens as a sheet over
        // the list, so the row carries no disclosure chevron promising a push.
        ForEach(section.rows) { book in
            Button {
                onBookTapped(book)
            } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.rating,
                    series: book.series,
                    statusTag: showsStatus ? book.status : nil,
                    genre: book.genre,
                    subgenre: book.subgenres.first,
                    language: book.language,
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
        EmptyStateView(
            systemImage: "books.vertical",
            title: "Votre bibliothèque est vide",
            message: "Scannez la couverture d'un livre pour commencer.",
            primary: .init("Scanner un livre", systemImage: "camera") { onAdd() }
        )
    }
}

#Preview("Par date") {
    @Previewable @State var mode: LibraryMode = .all
    @Previewable @State var statusFilter: ReadingStatus?
    let saga = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main)
    let saga2 = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 2, kind: .main)
    let books = [
        Book(id: "2", title: "La Peur du sage", authors: ["Patrick Rothfuss"], genre: .fantasy, series: saga2, status: .reading, shelvedAt: .now),
        Book(id: "3", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead, hidden: true, shelvedAt: .now.addingTimeInterval(-86400)),
        Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], genre: .fantasy, series: saga, status: .read, rating: 5, shelvedAt: .now.addingTimeInterval(-60 * 86400)),
    ]

    NavigationStack {
        LibraryPage(
            mode: $mode,
            statusFilter: $statusFilter,
            sections: MonthSection.cut(books, on: \.shelvedAt),
            showsStatus: true,
            isLoading: false,
            errorMessage: nil,
            onRetry: {},
            onAdd: {},
            onBookTapped: { _ in }
        )
    }
}

#Preview("Vide") {
    @Previewable @State var mode: LibraryMode = .all
    @Previewable @State var statusFilter: ReadingStatus?

    NavigationStack {
        LibraryPage(
            mode: $mode,
            statusFilter: $statusFilter,
            sections: [],
            isLoading: false,
            errorMessage: nil,
            onRetry: {},
            onAdd: {},
            onBookTapped: { _ in }
        )
    }
}
