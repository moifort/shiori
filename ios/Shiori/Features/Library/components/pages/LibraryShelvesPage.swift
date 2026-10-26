import SwiftUI

/// Everything the Library tab's entry screen, or a genre page, can ask for.
enum LibraryShelvesAction {
    case openBook(Book)
    case openShelf(BookShelf)
    case openSeriesShelf
    case openSeries(FollowedSeries)
    case openAuthors
    case openAuthor(FollowedAuthor)
    case openGenre(BookGenre)
    case selectFormat(BookFormat?)
    case selectSubgenre(String?)
    case search
    case menu(Book, BookQuickAction)
    case refresh
}

/// The Library tab's entry screen, as the TV app lays out its library: the
/// bar's title with the search beside it, the format pills, then rails in a fixed
/// order — what moved last, the pile, the series, the authors, the books read,
/// the favourites, the genres — and the rows of every book and of those given
/// up on. A rail with nothing in it is not drawn, and no header counts.
///
/// A genre page is the same screen narrowed to a genre: its subgenres take
/// the pills, and the rails are its pile, its books read, its series and its
/// authors.
struct LibraryShelvesPage: View {
    let shelves: LibraryShelves
    /// The format pills offered, and the one chosen.
    let formats: [BookFormat]
    let selectedFormat: BookFormat?
    /// A genre page: its subgenre pills, and the one chosen.
    var genre: BookGenre?
    var subgenres: [String] = []
    var selectedSubgenre: String?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (LibraryShelvesAction) -> Void

    /// Whether the entry screen's bar shows its title and search, as the
    /// home's does: shown at the top, sent away while scrolling down, called
    /// back by scrolling up, as Safari brings its bar back.
    @State private var barCalled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                if shelves.isEmpty {
                    emptyState
                } else if genre == nil {
                    entryRails
                } else {
                    genreRails
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, offset in
            guard genre == nil else { return }
            let called = if offset <= 6 { true }
                else if offset > old + 4 { false }
                else if offset < old - 4 { true }
                else { barCalled }
            guard called != barCalled else { return }
            withAnimation(.smooth(duration: 0.25)) { barCalled = called }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(genre?.label ?? String(localized: "Bibliothèque"))
        .modifier(EntryBar(isEntry: genre == nil, isCalled: barCalled) { onAction(.search) })
        .refreshable { onAction(.refresh) }
        .overlay(alignment: .top) {
            if isLoading, shelves.isEmpty { ProgressView().padding(.top, 120) }
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            if genre != nil, !subgenres.isEmpty {
                FilterPills(
                    pills: subgenres.map { FilterPills.Pill(id: $0, label: $0) },
                    selected: selectedSubgenre
                ) { onAction(.selectSubgenre($0)) }
            } else if formats.count > 1 {
                FilterPills(
                    pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                    selected: selectedFormat?.rawValue
                ) { id in onAction(.selectFormat(id.flatMap(BookFormat.init(rawValue:)))) }
            }
        }
    }

    // MARK: - Rails

    @ViewBuilder private var entryRails: some View {
        bookRail(.recent, shelves.recent, context: .recent)
        bookRail(.toRead, shelves.toRead, context: .pile)
        seriesRail
        authorsRail
        bookRail(.read, shelves.readRecently, context: .read)
        bookRail(.loved, shelves.favorites, context: .lovedByYear)
        if !shelves.genres.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Par genre", style: .inline)
                    .padding(.horizontal, 20)
                GenreTileGrid(genres: shelves.genres) { onAction(.openGenre($0)) }
            }
        }
        ShelfLinkRows(showsDropped: shelves.hasDropped) { onAction(.openShelf($0)) }
    }

    @ViewBuilder private var genreRails: some View {
        bookRail(.toRead, shelves.toRead, context: .pile)
        bookRail(.read, shelves.readRecently, context: .read, title: "Lus")
        seriesRail
        authorsRail
    }

    @ViewBuilder
    private func bookRail(
        _ shelf: BookShelf,
        _ books: [Book],
        context: PosterLabel.Context,
        title: LocalizedStringKey? = nil
    ) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: title ?? LocalizedStringKey(shelf.title), style: .inline) {
                    onAction(.openShelf(shelf))
                }
                .padding(.horizontal, 20)
                PosterRow(
                    items: books.map { .init(book: $0, label: PosterLabel.of($0, in: context)) },
                    onOpen: { onAction(.openBook($0)) },
                    onMenu: { onAction(.menu($0, $1)) }
                )
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
            .accessibilityIdentifier("library-rail-\(shelf.rawValue)")
        }
    }

    @ViewBuilder private var seriesRail: some View {
        if !shelves.series.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Séries", style: .inline) { onAction(.openSeriesShelf) }
                    .padding(.horizontal, 20)
                SeriesCardRail(series: shelves.series) { onAction(.openSeries($0)) }
            }
            .accessibilityIdentifier("library-rail-series")
        }
    }

    @ViewBuilder private var authorsRail: some View {
        if !shelves.authors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Auteurs", style: .inline) { onAction(.openAuthors) }
                    .padding(.horizontal, 20)
                AuthorPortraitRail(authors: shelves.authors) { onAction(.openAuthor($0)) }
            }
            .accessibilityIdentifier("library-rail-authors")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if let errorMessage, !isLoading {
            EmptyState.failure("Bibliothèque indisponible", message: errorMessage) {
                onAction(.refresh)
            }
        } else if !isLoading {
            EmptyState(
                systemImage: "books.vertical",
                title: genre == nil ? "Votre bibliothèque est vide" : "Aucun livre de ce genre",
                message: "Scannez la couverture d'un livre pour commencer."
            )
        }
    }
}

/// The entry screen's bar, drawn as the home's: the page's name on the left
/// and the search on the right, both going away together. A genre page keeps
/// the system's large title.
private struct EntryBar: ViewModifier {
    let isEntry: Bool
    let isCalled: Bool
    let onSearch: () -> Void

    func body(content: Content) -> some View {
        if isEntry {
            content
                // The bar keeps the title for VoiceOver and the Back button,
                // and draws its own on the left.
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) { Text(verbatim: "").accessibilityHidden(true) }
                    if isCalled {
                        ToolbarItem(placement: .topBarLeading) {
                            Text("Bibliothèque")
                                .font(.title2.weight(.bold))
                                .fixedSize()
                                .accessibilityHidden(true)
                        }
                        .sharedBackgroundVisibility(.hidden)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: onSearch) {
                                Label("Rechercher", systemImage: "magnifyingglass")
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("library-search")
                        }
                    }
                }
        } else {
            content
        }
    }
}

extension BookFormat {
    /// The format as a pill names the books of it: "Livres", "Mangas", "BD".
    var shelfLabel: String {
        switch self {
        case .book: String(localized: "Livres")
        case .audiobook: String(localized: "Livres audio")
        case .bandeDessinee: String(localized: "BD")
        case .comic: String(localized: "Comics")
        case .manga: String(localized: "Mangas")
        }
    }
}

#Preview("Library") {
    NavigationStack {
        LibraryShelvesPage(
            shelves: Showcase.libraryShelves(view: ShelvesView()),
            formats: Showcase.libraryShelves(view: ShelvesView()).formats,
            selectedFormat: nil,
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}

#Preview("Genre") {
    NavigationStack {
        LibraryShelvesPage(
            shelves: Showcase.libraryShelves(view: ShelvesView(genre: .scienceFiction)),
            formats: [],
            selectedFormat: nil,
            genre: .scienceFiction,
            subgenres: Showcase.libraryShelves(view: ShelvesView(genre: .scienceFiction)).subgenres,
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}

#Preview("Empty") {
    NavigationStack {
        LibraryShelvesPage(shelves: LibraryShelves(), formats: [], selectedFormat: nil, isLoading: false, errorMessage: nil) { _ in }
    }
}
