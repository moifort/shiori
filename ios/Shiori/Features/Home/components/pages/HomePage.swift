import SwiftUI

/// Everything the dashboard can ask for: each card opens the list it counts.
enum HomeAction {
    /// A tile or a shelf: the Library tab on the books it counts.
    case showLibrary(LibraryRequest)
    /// The progress card's header: the Series tab on the sagas in progress.
    case showSeries(SeriesRequest)
    /// A row of the progress card.
    case openSeries(String)
    case openBook(Book)
    case openGenres
    /// The prompt that leads an empty library.
    case scan
    /// The releases header.
    case showDiscover
    /// A volume just out or announced, or a recording awaited.
    case openRelease(HomeRelease)
    /// The friends' favourites header.
    case showShared
    case openFriendFavorite(FriendFavorite)
    case openDiscovery(Suggestion)
}

/// The dashboard laid out top to bottom. Stateless: the coordinator hands it the
/// figures and receives the taps. Every widget is drawn from the first book on;
/// one with nothing to show yet says what will fill it.
struct HomePage: View {
    let dashboard: Dashboard
    /// The volumes just out, the newest first, then the next one announced of
    /// each saga followed and the recordings awaited, the soonest first.
    var releases: [HomeRelease] = []
    /// What the reader's friends hearted lately, the newest first.
    var friendFavorites: [FriendFavorite] = []
    /// The month's discoveries, chosen for the reader.
    var discoveries: MonthlyDiscoveries?
    let onAction: (HomeAction) -> Void

    /// The page's width and where an open iPhone Duo folds across it, which
    /// place the columns on either side of the fold.
    @State private var geometry = PageGeometry()
    /// Regular on the Duo's inner screen, the only width the cards sit in two
    /// columns at: a phone held upright, or the Duo folded, is compact.
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let columns {
                    // Unfolded, a single column would stretch each card over
                    // the whole screen with three covers in it: the figures on
                    // one side, the shelves on the other.
                    HStack(alignment: .top, spacing: columns.gutter) {
                        VStack(spacing: 16) { figureCards }
                            .frame(width: columns.leading)
                        VStack(spacing: 16) { shelfCards }
                            .frame(width: columns.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    scanPromptIfEmpty
                    statTiles
                    genresCard
                    chartCard
                    shelfCards
                    lastFinishedCard
                    seriesCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .onGeometryChange(for: PageGeometry.self) {
            PageGeometry(width: $0.size.width, fold: $0.foldSpan(includeInactive: true))
        } action: { geometry = $0 }
        .background(Color(.systemGroupedBackground))
    }

    /// What the page knows of its own frame: enough to lay out its columns.
    private struct PageGeometry: Equatable {
        var width: CGFloat = 0
        var fold: ClosedRange<CGFloat>?
    }

    /// The two columns' widths and the space between them, nil for one column.
    private var columns: HomeColumns? {
        HomeColumns(width: geometry.width, fold: geometry.fold, isRegularWidth: sizeClass == .regular)
    }

    /// The library at a glance and what it is made of, the left column once
    /// unfolded: the tiles and the scan prompt too, which would otherwise
    /// straddle the fold.
    @ViewBuilder private var figureCards: some View {
        scanPromptIfEmpty
        statTiles
        genresCard
        chartCard
        lastFinishedCard
        seriesCard
    }

    /// The shelves of covers, the right column once unfolded.
    @ViewBuilder private var shelfCards: some View {
        readingShelf
        discoveriesShelf
        releasesShelf
        friendFavoritesShelf
    }

    /// The one thing a reader can do from an empty dashboard, above the cards
    /// it will fill.
    @ViewBuilder private var scanPromptIfEmpty: some View {
        if dashboard.libraryIsEmpty {
            scanPrompt
        }
    }

    /// The library at a glance first, then what it is made of.
    private var statTiles: some View {
        StatTilesRow(
            readCount: dashboard.readCount,
            favoriteCount: dashboard.favoriteCount,
            toReadCount: dashboard.toReadCount,
            onReadTapped: { onAction(.showLibrary(LibraryRequest(filter: .status(.read)))) },
            onFavoritesTapped: { onAction(.showLibrary(LibraryRequest(filter: .favorites))) },
            onPileTapped: { onAction(.showLibrary(LibraryRequest(filter: .status(.toRead)))) }
        )
    }

    /// The genres read, as a bar.
    @ViewBuilder private var genresCard: some View {
        GenresWidget(
            genres: dashboard.genres,
            onTapped: { onAction(.openGenres) }
        )
    }

    /// Books, pages or hours, year by year or month by month.
    @ViewBuilder private var chartCard: some View {
        ReadingChartWidget(
            currentYear: dashboard.currentYear,
            booksPerYear: dashboard.booksPerYear,
            pagesPerMonth: dashboard.pagesPerMonth,
            hoursPerMonth: dashboard.hoursPerMonth,
            hasAudiobooks: dashboard.hasAudiobooks,
            hasPrintedBooks: dashboard.hasPrintedBooks
        )
    }

    /// The books open now.
    @ViewBuilder private var readingShelf: some View {
        BookShelfSection(
            title: "En cours",
            books: dashboard.reading,
            caption: Self.startedCaption,
            emptyMessage: "Aucun livre en cours de lecture.",
            onHeaderTapped: { onAction(.showLibrary(LibraryRequest(filter: .status(.reading)))) },
            onBookTapped: { onAction(.openBook($0)) }
        )
        .accessibilityIdentifier("home-reading")
    }

    /// The month's discoveries.
    @ViewBuilder private var discoveriesShelf: some View {
        // As Découvrir draws them: the first two with why, the
        // others' covers under them.
        if let discoveries, discoveries.status == .ready, !discoveries.suggestions.isEmpty {
            DiscoveriesShelfSection(
                discoveries: discoveries,
                onHeaderTapped: { onAction(.showDiscover) },
                onOpen: { onAction(.openDiscovery($0)) }
            )
            .accessibilityIdentifier("home-discoveries")
        }
    }

    /// The volumes just out or announced.
    @ViewBuilder private var releasesShelf: some View {
        // Unlike the reader's own cards, these two are news: with
        // nothing to announce they are left out rather than sketched.
        if !releases.isEmpty {
            BookShelfSection(
                title: "Nouveautés",
                books: releases.map(Self.releaseTile),
                caption: { tile in
                    guard let release = release(of: tile) else { return tile.authorLine }
                    guard let date = release.date, ReleaseDateText.isUpcoming(date) else {
                        return String(localized: "Disponible")
                    }
                    return ReleaseDateText.short(date)
                },
                // Out already in green, still to come in the book
                // page's orange.
                captionTint: { tile in
                    guard let release = release(of: tile) else { return nil }
                    return release.date.map { ReleaseDateText.isUpcoming($0) } ?? false
                        ? .orange : .green
                },
                emptyMessage: "",
                onHeaderTapped: { onAction(.showDiscover) },
                onBookTapped: { tile in
                    if let release = release(of: tile) { onAction(.openRelease(release)) }
                }
            )
            .accessibilityIdentifier("home-releases")
        }
    }

    /// What the reader's friends hearted lately.
    @ViewBuilder private var friendFavoritesShelf: some View {
        if !friendFavorites.isEmpty {
            BookShelfSection(
                title: "Nouveaux favoris de vos amis",
                books: friendFavorites.map(\.tile),
                caption: { tile in
                    friendFavorites.first { $0.tile.id == tile.id }?.friendDisplayName ?? ""
                },
                emptyMessage: "",
                onHeaderTapped: { onAction(.showShared) },
                onBookTapped: { tile in
                    if let favorite = friendFavorites.first(where: { $0.tile.id == tile.id }) {
                        onAction(.openFriendFavorite(favorite))
                    }
                }
            )
            .accessibilityIdentifier("home-friend-favorites")
        }
    }

    /// The book finished last.
    @ViewBuilder private var lastFinishedCard: some View {
        LastFinishedCard(book: dashboard.lastFinished) { onAction(.openBook($0)) }
    }

    /// The sagas in progress.
    @ViewBuilder private var seriesCard: some View {
        SeriesProgressWidget(
            series: dashboard.series,
            onHeaderTapped: { onAction(.showSeries(SeriesRequest(state: .inProgress))) },
            onSeriesTapped: { onAction(.openSeries($0)) }
        )
    }

    private var scanPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Votre bibliothèque est vide").font(.headline)
            } icon: {
                Image(systemName: "books.vertical").foregroundStyle(.tint)
            }
            Text("Scannez la couverture d'un livre pour commencer. Chaque carte ci-dessous se remplira avec vos lectures.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { onAction(.scan) } label: {
                Label("Scanner un livre", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("home-scan")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    /// The release a tile draws.
    private func release(of tile: Book) -> HomeRelease? {
        releases.first { Self.releaseTile($0).id == tile.id }
    }

    /// A release drawn as a book, as Découvrir draws it: a volume with its saga
    /// as a tag, the headphones on the cover of a recording.
    private static func releaseTile(_ release: HomeRelease) -> Book {
        switch release {
        case let .volume(volume): volumeTile(volume)
        case let .awaited(edition): edition.cover
        }
    }

    private static func volumeTile(_ release: DiscoveryVolume) -> Book {
        let series = release.saga.series
        let volume = release.volume
        return Book(
            id: "release-\(series.id)-\(volume.number)",
            title: volume.title,
            authors: series.author.map { [$0] } ?? [],
            format: series.isAudio ? .audiobook : .book,
            genre: series.genre,
            language: series.language,
            series: SeriesMembership(id: series.seriesId, name: series.name, volume: volume.number, kind: .main),
            coverURL: volume.coverURL,
            status: .toRead
        )
    }

    /// A recording says how far the player got; a book says how long it has
    /// been open, since nobody tracks its pages.
    private static func startedCaption(_ book: Book) -> String {
        if let progress = book.listeningProgressLabel {
            return String(localized: "\(progress) écouté")
        }
        guard let startedAt = book.startedAt else { return book.authorLine }
        let days = startedAt.daysAgo()
        return days == 0
            ? String(localized: "commencé aujourd'hui")
            : String(localized: "depuis \(days) j")
    }
}

extension Dashboard {
    static let preview = Dashboard(
        currentYear: 2026,
        booksPerYear: [
            .init(year: 2022, count: 9), .init(year: 2023, count: 14), .init(year: 2024, count: 21),
            .init(year: 2025, count: 16), .init(year: 2026, count: 18),
        ],
        pagesPerMonth: [410, 720, 380, 910, 760, 600, 1180, 1100, 260, 0, 0, 0].enumerated()
            .map { .init(month: $0.offset + 1, pages: $0.element) },
        hoursPerMonth: [6, 11, 4, 0, 9, 14, 7, 12, 3, 0, 0, 0].enumerated()
            .map { .init(month: $0.offset + 1, hours: $0.element) },
        reading: [
            Book(id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"], status: .reading,
                 startedAt: .now.addingTimeInterval(-12 * 86400)),
            Book(id: "2", title: "One Piece", authors: ["Eiichirō Oda"], status: .reading,
                 startedAt: .now.addingTimeInterval(-2 * 86400)),
            Book(id: "3", title: "Dune", authors: ["Frank Herbert"], status: .reading,
                 startedAt: .now.addingTimeInterval(-41 * 86400)),
            Book(id: "4", title: "Blacksad", authors: ["Juan Díaz Canales"], status: .reading,
                 startedAt: .now.addingTimeInterval(-5 * 86400)),
        ],
        lastFinished: Book(
            id: "9", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read, rating: 5,
            startedAt: .now.addingTimeInterval(-13 * 86400), finishedAt: .now.addingTimeInterval(-4 * 86400)
        ),
        toReadCount: 27,
        readCount: 142,
        genres: [
            .init(genre: .fantasy, count: 7), .init(genre: .scienceFiction, count: 4),
            .init(genre: .adventure, count: 3), .init(genre: .crime, count: 2), .init(genre: nil, count: 2),
        ],
        series: [
            .init(id: "a", name: "One Piece", readCount: 107, totalCount: 110, favorite: true),
            .init(id: "b", name: "Chronique du tueur de roi", readCount: 1, totalCount: 2, rating: 4),
        ],
        favoriteCount: 6,
        hasAudiobooks: true,
        libraryIsEmpty: false
    )
}

extension Dashboard {
    /// A library with one book just added: every widget drawn, most of them
    /// saying what will fill them.
    static let firstBook = Dashboard(
        currentYear: 2026,
        booksPerYear: (2018...2026).map { .init(year: $0, count: 0) },
        pagesPerMonth: (1...12).map { .init(month: $0, pages: 0) },
        hoursPerMonth: (1...12).map { .init(month: $0, hours: 0) },
        reading: [],
        lastFinished: nil,
        toReadCount: 1,
        genres: [],
        series: [],
        libraryIsEmpty: false
    )
}

#Preview("With data") {
    NavigationStack {
        HomePage(dashboard: .preview, discoveries: .preview) { _ in }
            .navigationTitle("Accueil")
    }
}

#Preview("First book") {
    NavigationStack {
        HomePage(dashboard: .firstBook) { _ in }
            .navigationTitle("Accueil")
    }
}

#Preview("Unfolded", traits: .fixedLayout(width: 951, height: 669)) {
    NavigationStack {
        HomePage(dashboard: .preview, discoveries: .preview) { _ in }
            .navigationTitle("Accueil")
    }
    .environment(\.horizontalSizeClass, .regular)
}
