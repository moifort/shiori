import SwiftUI

/// Everything the home screen can ask for: each row opens what it shows.
enum HomeAction {
    /// A row's header: the Library tab on the books it lists.
    case showLibrary(LibraryRequest)
    /// "Mes séries"'s header: the Series tab on the sagas in progress.
    case showSeries(SeriesRequest)
    /// A card of "Mes séries".
    case openSeries(String)
    case openBook(Book)
    /// The figures over the hero: the statistics, beside or over the page.
    case showStatistics
    /// The statistics' genre card.
    case openGenres
    /// The book read now, finished from its card: the screen asks for a
    /// rating, which the reader may pass.
    case finishBook(Book)
    /// The book read now, rated from its card.
    case rateBook(Book)
    /// The prompt that leads an empty library.
    case scan
    /// An empty library's start rows: Audible or Kindle to connect.
    case connectSource(ImportSource)
    /// An empty library's start rows: the Partagé tab, where a friend is
    /// invited or an invitation entered.
    case showShared
    /// "Nouveautés"'s header, and the hero's way to every discovery.
    case showDiscover
    /// A volume just out or announced, or a recording awaited.
    case openRelease(HomeRelease)
    case openFriendFavorite(FriendFavorite)
    case openDiscovery(Suggestion)
    /// A discovery put on the shelf from the carousel's "+": on the pile, or
    /// read already.
    case addDiscovery(Suggestion, ReadingStatus)
    /// A discovery's edition awaited from the carousel's "+".
    case awaitDiscovery(Suggestion, ReleaseFormat)
}

/// The home screen in the TV app's grammar: a hero with the month's discovery
/// over its cover's colours, the library's figures in one line, then rows on
/// the page without cards around them — the books open now, the pile, what is
/// new, the sagas in progress. A row with nothing to show is not drawn, title
/// and all. Stateless: the coordinator hands it the figures and receives the
/// taps.
///
/// On a phone or the folded Duo, the month's discoveries open the page as the
/// TV app's carousel, one page each under empty bars. Laid wide on the Duo's
/// inner screen with nothing open beside it, the rows stand in two columns
/// under a hero that shows the month's other discoveries too; beside a detail,
/// one column under the same hero.
struct HomePage: View {
    let dashboard: Dashboard
    /// The volumes just out, the newest first, then the next one announced of
    /// each saga followed and the recordings awaited, the soonest first.
    var releases: [HomeRelease] = []
    /// What the reader's friends hearted lately, the newest first.
    var friendFavorites: [FriendFavorite] = []
    /// The month's discoveries, chosen for the reader.
    var discoveries: MonthlyDiscoveries?
    /// The month's selection is being made: a phone's hero waits on it.
    var isSearchingDiscoveries = false
    /// Whether the page has the Duo's inner screen to itself.
    var isSideBySide = false
    /// A phone or the folded Duo: the discoveries open the page as a carousel.
    var isCompact = false
    var today: Date = .now
    /// Whether the bar's title and buttons are called for over the hero:
    /// hidden as the page opens, scrolled by the bar's height, and while the
    /// reader scrolls down; called back at the very top, where the bar has
    /// its room above the page, and by scrolling up below the hero, as Safari
    /// brings its bar back.
    var onBarCalled: (Bool) -> Void = { _ in }
    /// Whether the page has left the top: the bar's blur comes in then, so the
    /// rows never run under the status bar bare.
    var onLeftTop: (Bool) -> Void = { _ in }
    let onAction: (HomeAction) -> Void

    /// How far the page is pulled down past its top.
    @State private var pull: CGFloat = 0
    /// Where the page stands, set once to open it under the bar.
    @State private var position = ScrollPosition()
    @State private var openedUnderBar = false

    /// How far a page that opens on a hero is scrolled as it opens: the
    /// bar's height, so the page starts just under the status bar with the
    /// bar out of sight, as Mail tucks its search field away. Scrolled back to
    /// the very top, the page leaves the bar its room.
    static let openingOffset: CGFloat = 50
    /// How far past that the page scrolls before scrolling up calls the bar:
    /// above it, the bar would land over the figures.
    private static let figuresClearance: CGFloat = 70

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if opensOnHero {
                    // The figures head the page, over the hero's colours,
                    // drawn above the backdrop that runs up under them. At
                    // zero, before the first book, they are dimmed: the shape
                    // of the page is announced, not its figures.
                    figures
                        .environment(\.colorScheme, .dark)
                        .opacity(dashboard.libraryIsEmpty ? 0.45 : 1)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .zIndex(1)
                }
                if showsCarousel {
                    HomeHeroCarousel(
                        items: heroItems,
                        onOpenRelease: { onAction(.openRelease($0)) },
                        onOpen: { onAction(.openDiscovery($0)) },
                        onAdd: { onAction(.addDiscovery($0, $1)) },
                        onAwait: { onAction(.awaitDiscovery($0, $1)) },
                        pull: pull
                    )
                } else if dashboard.libraryIsEmpty, opensOnHero {
                    HomeEmptyHero { onAction(.scan) }
                } else if opensOnHero {
                    HomeSearchingHero(
                        month: discoveries?.month ?? MonthlyDiscoveries.month(of: today),
                        bookCount: dashboard.readCount + dashboard.reading.count + dashboard.toReadCount,
                        covers: dashboard.coverURLsForOrbit
                    )
                } else {
                    HomeHero(
                        discoveries: shownDiscoveries,
                        date: today,
                        isWide: isSideBySide,
                        onOpen: { onAction(.openDiscovery($0)) },
                        onShowAll: { onAction(.showDiscover) }
                    )
                }
                VStack(alignment: .leading, spacing: 30) {
                    if dashboard.libraryIsEmpty {
                        if opensOnHero {
                            startRows
                        } else {
                            scanPrompt
                        }
                    } else if !opensOnHero {
                        figures
                    }
                    if isSideBySide {
                        HStack(alignment: .top, spacing: 36) {
                            VStack(alignment: .leading, spacing: 30) {
                                readingRow
                                pileRow
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            newsRow
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        readingRow
                        pileRow
                        newsRow
                    }
                    seriesRow
                }
                .padding(.horizontal, 20)
                .padding(.top, opensOnHero ? 16 : 14)
                .padding(.bottom, 32)
            }
        }
        .scrollPosition($position)
        .onChange(of: opensOnHero, initial: true) { _, shows in
            guard shows, !openedUnderBar else { return }
            openedUnderBar = true
            position.scrollTo(y: Self.openingOffset)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, offset in
            // Past the hero, the blur keeps the rows off the status bar.
            onLeftTop(offset > Self.openingOffset + 80)
            // At the very top, or bouncing above it, the bar has its room
            // over the page: it shows. Scrolling down sends it away; scrolling
            // up calls it back once below the figures, where it covers none.
            if offset <= 6 {
                onBarCalled(true)
            } else if offset > old + 4 {
                onBarCalled(false)
            } else if offset < old - 4, offset > Self.openingOffset + Self.figuresClearance {
                onBarCalled(true)
            }
        }
        // Only past the top, while the reader pulls: scrolling leaves it at 0.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(-(geometry.contentOffset.y + geometry.contentInsets.top), 0)
        } action: { _, pulled in
            pull = pulled
        }
        .background(Color(.systemGroupedBackground))
    }

    private var shownDiscoveries: [Suggestion] {
        discoveries?.shownOnHome ?? []
    }

    /// What the carousel shows: the week's releases, then the discoveries.
    private var heroItems: [HomeHeroItem] {
        HomeHeroItem.items(releases: releases, discoveries: shownDiscoveries, today: today)
    }

    private var showsCarousel: Bool {
        isCompact && !heroItems.isEmpty
    }

    /// Whether the page opens on a hero that runs up under the bar: the
    /// carousel, the empty shelf's prompt before the first book, or the wait
    /// on the month's selection.
    private var opensOnHero: Bool {
        Self.opensOnHero(
            dashboard: dashboard,
            releases: releases,
            discoveries: discoveries,
            isSearchingDiscoveries: isSearchingDiscoveries,
            isCompact: isCompact,
            today: today
        )
    }

    /// The same test for the coordinator, which sets the bar up for a hero:
    /// on a phone, the carousel once a release is due this week or the
    /// month's choice is ready, the empty shelf's prompt before the first
    /// book, or the wait while the month's selection is made.
    static func opensOnHero(
        dashboard: Dashboard?,
        releases: [HomeRelease],
        discoveries: MonthlyDiscoveries?,
        isSearchingDiscoveries: Bool,
        isCompact: Bool,
        today: Date = .now
    ) -> Bool {
        guard isCompact, let dashboard else { return false }
        if dashboard.libraryIsEmpty { return true }
        let items = HomeHeroItem.items(releases: releases, discoveries: discoveries?.shownOnHome ?? [], today: today)
        return !items.isEmpty || isSearchingDiscoveries
    }

    /// A phone heads its rows as the TV app does, the chevron after the title.
    private var headerStyle: RowHeader.Style {
        isCompact ? .inline : .trailing
    }

    // MARK: - Start rows

    /// Before the first book, in place of the shelves: the sources to
    /// connect, and the friends to read with.
    @ViewBuilder private var startRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Importer vos livres", style: .inline)
            ImportSourcesRow { onAction(.connectSource($0)) }
        }
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Partager", style: .inline) { onAction(.showShared) }
            FriendsInviteCard(onInvite: { onAction(.showShared) }, onEnterInvitation: { onAction(.showShared) })
        }
    }

    // MARK: - Figures

    private var figures: some View {
        HomeFiguresLine(
            year: dashboard.currentYear,
            readCount: dashboard.readThisYear,
            favoriteCount: dashboard.favoriteCount,
            toReadCount: dashboard.toReadCount,
            pagesRead: dashboard.pagesThisYear,
            hoursListened: dashboard.hoursThisYear,
            // A fourth column before the first book, so the line keeps the
            // balance it will have.
            showsPagesAtZero: dashboard.libraryIsEmpty
        ) {
            onAction(.showStatistics)
        }
    }

    // MARK: - Rows

    /// The books open now: the last one started leads, over its colours.
    @ViewBuilder private var readingRow: some View {
        if let lead = dashboard.reading.first {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "En cours", detail: String(localized: "tout voir"), style: headerStyle) {
                    onAction(.showLibrary(LibraryRequest(filter: .status(.reading))))
                }
                // A phone heads the row with the TV app's card; the open Duo
                // keeps the compact one, the others lined up under it.
                if isCompact {
                    ReadingFeatureCard(
                        book: lead,
                        caption: Self.openedCaption(lead),
                        onOpen: { onAction(.openBook(lead)) },
                        onFinish: { onAction(.finishBook(lead)) },
                        onOpenSeries: lead.series.map { series in { onAction(.openSeries(series.id)) } }
                    )
                } else {
                    ReadingLeadCard(
                        book: lead,
                        caption: Self.startedCaption(lead),
                        onOpen: { onAction(.openBook(lead)) },
                        onFinish: { onAction(.finishBook(lead)) },
                        onRate: { onAction(.rateBook(lead)) }
                    )
                }
                // The others under it on the open Duo; a phone keeps to the lead.
                if !isCompact, dashboard.reading.count > 1 {
                    CoverRow(
                        items: dashboard.reading.dropFirst().map {
                            .init(book: $0, caption: Self.startedCaption($0), captionTint: $0.listeningProgress == nil ? nil : .blue)
                        },
                        coverWidth: 64
                    ) { onAction(.openBook($0)) }
                }
            }
            .accessibilityIdentifier("home-reading")
        }
    }

    /// The pile, the book shelved last first.
    @ViewBuilder private var pileRow: some View {
        if !dashboard.toRead.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Pile à lire", detail: String(localized: "\(dashboard.toReadCount) à lire"), style: headerStyle) {
                    onAction(.showLibrary(LibraryRequest(filter: .status(.toRead))))
                }
                // A phone shelves the pile as the TV app does, the days in
                // each cover; the open Duo keeps the titles under them.
                if isCompact {
                    PosterRow(
                        items: dashboard.toRead.map { .init(book: $0, caption: Self.shelvedCaption($0)) }
                    ) { onAction(.openBook($0)) }
                } else {
                    CoverRow(
                        items: dashboard.toRead.map {
                            .init(book: $0, caption: Self.addedCaption($0), captionTint: ReadingStatus.toRead.tint)
                        }
                    ) { onAction(.openBook($0)) }
                }
            }
            .accessibilityIdentifier("home-pile")
        }
    }

    /// What is new: the volumes out or to come, then what friends hearted.
    /// Not before the first book: a new reader follows no saga and has no
    /// friend yet, and the friends card already says this row is where their
    /// favourites will land.
    @ViewBuilder private var newsRow: some View {
        let tiles = newsTiles
        if !tiles.isEmpty, !dashboard.libraryIsEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Nouveautés", detail: String(localized: "Découvrir"), style: headerStyle) {
                    onAction(.showDiscover)
                }
                // A phone shelves them as the pile, the day out or "Disponible"
                // in each cover; the open Duo keeps its tiles.
                if isCompact {
                    PosterRow(
                        items: tiles.map { .init(book: $0.book, caption: $0.caption, open: $0.open) }
                    ) { _ in }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(tiles, id: \.id) { tile in
                            NewsTile(book: tile.book, caption: tile.caption, captionTint: tile.tint, onOpen: tile.open)
                        }
                    }
                }
            }
            .accessibilityIdentifier("home-releases")
        }
    }

    private static let seriesCardHeight: CGFloat = 176

    /// The sagas in progress, the last one shelved first.
    @ViewBuilder private var seriesRow: some View {
        if !dashboard.series.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RowHeader(title: "Mes séries", detail: String(localized: "tout voir"), style: headerStyle) {
                    onAction(.showSeries(SeriesRequest(state: .inProgress)))
                }
                if isCompact {
                    // Two rows that scroll sideways, the cards wide enough
                    // for the next column to be cut by the edge: the row says
                    // it goes on.
                    ScrollView(.horizontal) {
                        // Spaced as the poster rows above.
                        LazyHGrid(
                            rows: [GridItem(.fixed(Self.seriesCardHeight), spacing: 13),
                                   GridItem(.fixed(Self.seriesCardHeight), spacing: 13)],
                            spacing: 13
                        ) {
                            ForEach(dashboard.series) { series in
                                SeriesShowCard(series: series, tag: releaseTag(of: series)) {
                                    onAction(.openSeries(series.id))
                                }
                                .frame(width: 250, height: Self.seriesCardHeight)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                } else {
                    let columns = isSideBySide ? 4 : 2
                    // Whole rows only, past the first: the rest is a tap away.
                    let shown = dashboard.series.count > columns
                        ? Array(dashboard.series.prefix(dashboard.series.count / columns * columns))
                        : dashboard.series
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                        spacing: 10
                    ) {
                        ForEach(shown) { series in
                            SeriesShowCard(series: series, tag: releaseTag(of: series)) {
                                onAction(.openSeries(series.id))
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("home-series")
        }
    }

    // MARK: - News

    private struct NewsItem {
        let id: String
        let book: Book
        let caption: String
        let tint: Color?
        let open: () -> Void
    }

    /// Six releases at most, then four friends' favourites: the rest are
    /// Découvrir's.
    private var newsTiles: [NewsItem] {
        let releaseItems = releases.prefix(6).map { release in
            let tile = Self.releaseTile(release)
            let upcoming = release.date.map { ReleaseDateText.isUpcoming($0) } ?? false
            return NewsItem(
                id: release.id,
                book: tile,
                caption: upcoming ? release.date.map(ReleaseDateText.short) ?? "" : String(localized: "Disponible"),
                tint: upcoming ? .orange : .green,
                open: { onAction(.openRelease(release)) }
            )
        }
        let favoriteItems = friendFavorites.prefix(4).map { favorite in
            NewsItem(
                id: "favorite-\(favorite.id)",
                book: favorite.tile,
                // A poster has room for the name alone, after a heart.
                caption: isCompact
                    ? "♥ \(favorite.friendDisplayName)"
                    : String(localized: "\(favorite.friendDisplayName) l'a adoré"),
                tint: nil,
                open: { onAction(.openFriendFavorite(favorite)) }
            )
        }
        // An even count on the open Duo: the grid's last row never ends on a
        // hole. A phone's row scrolls, and keeps them all.
        let items = releaseItems + favoriteItems
        if isCompact { return items }
        return items.count > 1 ? Array(items.prefix(items.count / 2 * 2)) : items
    }

    /// The saga's news, said on its card: its next volume out, or to come.
    private func releaseTag(of series: Dashboard.SeriesProgress) -> (text: String, isOut: Bool)? {
        for release in releases {
            guard case let .volume(volume) = release, volume.saga.series.seriesId == series.id else { continue }
            let number = volume.volume.number
            guard let date = volume.volume.date, ReleaseDateText.isUpcoming(date) else {
                return (String(localized: "Tome \(number) disponible"), true)
            }
            return (String(localized: "Tome \(number) · \(ReleaseDateText.short(date))"), false)
        }
        return nil
    }

    // MARK: - Empty library

    private var scanPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Votre bibliothèque est vide").font(.headline)
            } icon: {
                Image(systemName: "books.vertical").foregroundStyle(.tint)
            }
            Text("Scannez la couverture d'un livre pour commencer. Chaque rangée ci-dessous se remplira avec vos lectures.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { onAction(.scan) } label: {
                Label("Scanner un livre", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityIdentifier("home-scan")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    // MARK: - Captions

    /// A release drawn as a book, as Découvrir draws it: a volume with its saga
    /// as a tag, the headphones on the cover of a recording.
    static func releaseTile(_ release: HomeRelease) -> Book {
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
    static func startedCaption(_ book: Book) -> String {
        if let progress = book.listeningProgressLabel {
            return String(localized: "\(progress) écouté")
        }
        guard let startedAt = book.startedAt else { return book.authorLine }
        let days = startedAt.daysAgo()
        return days == 0
            ? String(localized: "commencé aujourd'hui")
            : String(localized: "depuis \(days) j")
    }

    /// How long a book has been open, whatever its format: the TV app's card
    /// says how far a recording got on its own bar.
    static func openedCaption(_ book: Book) -> String {
        guard let startedAt = book.startedAt else { return book.authorLine }
        let days = startedAt.daysAgo()
        return days == 0
            ? String(localized: "commencé aujourd'hui")
            : String(localized: "depuis \(days) j")
    }

    /// How long a book has been on the pile, set in its cover in the largest
    /// unit that fits: "Aujourd'hui", "Hier", "10 jours", "2 mois", "1 an".
    static func shelvedCaption(_ book: Book) -> String {
        guard let addedAt = book.addedAt else { return book.authorLine }
        let days = addedAt.daysAgo()
        switch days {
        case ..<1: return String(localized: "Aujourd'hui")
        case 1: return String(localized: "Hier")
        case ..<30: return String(localized: "\(days) jours")
        case ..<60: return String(localized: "1 mois")
        case ..<365: return String(localized: "\(days / 30) mois")
        case ..<730: return String(localized: "1 an")
        default: return String(localized: "\(days / 365) ans")
        }
    }

    /// When a book joined the pile.
    static func addedCaption(_ book: Book) -> String {
        guard let addedAt = book.addedAt else { return book.authorLine }
        switch addedAt.daysAgo() {
        case 0: return String(localized: "ajouté aujourd'hui")
        case 1: return String(localized: "ajouté hier")
        case let days: return String(localized: "il y a \(days) j")
        }
    }
}

extension MonthlyDiscoveries {
    /// What the home screen's hero shows: nothing until the month's choice is
    /// ready.
    var shownOnHome: [Suggestion] {
        status == .ready ? suggestions : []
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
        toRead: [
            Book(id: "5", title: "Fourth Wing", authors: ["Rebecca Yarros"], status: .toRead,
                 addedAt: .now.addingTimeInterval(-86400)),
            Book(id: "6", title: "Ubik", authors: ["Philip K. Dick"], status: .toRead,
                 addedAt: .now.addingTimeInterval(-6 * 86400)),
            Book(id: "7", title: "1984", authors: ["George Orwell"], status: .toRead,
                 addedAt: .now.addingTimeInterval(-20 * 86400)),
        ],
        lastFinished: Book(
            id: "9", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read, rating: 5,
            startedAt: .now.addingTimeInterval(-13 * 86400), finishedAt: .now.addingTimeInterval(-4 * 86400)
        ),
        toReadCount: 27,
        readCount: 142,
        pagesRead: 41_230,
        hoursListened: 212,
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
    /// The covers the wait on the month's selection turns around the model:
    /// the books open, the pile, the one finished last — a handful.
    var coverURLsForOrbit: [URL] {
        var seen: Set<URL> = []
        return (reading + toRead + [lastFinished].compactMap { $0 })
            .compactMap(\.coverURL)
            .filter { seen.insert($0).inserted }
            .prefix(8)
            .map { $0 }
    }

    /// No book yet: the phone opens on the empty shelf's prompt and its
    /// start rows.
    static let empty = Dashboard(
        currentYear: 2026,
        booksPerYear: (2018...2026).map { .init(year: $0, count: 0) },
        pagesPerMonth: (1...12).map { .init(month: $0, pages: 0) },
        hoursPerMonth: (1...12).map { .init(month: $0, hours: 0) },
        reading: [],
        lastFinished: nil,
        toReadCount: 0,
        genres: [],
        series: [],
        libraryIsEmpty: true
    )

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
    }
}

#Preview("Phone") {
    NavigationStack {
        HomePage(dashboard: .preview, discoveries: .preview, isCompact: true) { _ in }
    }
}

#Preview("First book") {
    NavigationStack {
        HomePage(dashboard: .firstBook) { _ in }
    }
}

#Preview("Empty, phone") {
    NavigationStack {
        HomePage(dashboard: .empty, isCompact: true) { _ in }
    }
}

#Preview("Searching, phone") {
    NavigationStack {
        HomePage(dashboard: .preview, isSearchingDiscoveries: true, isCompact: true) { _ in }
    }
}

#Preview("Unfolded", traits: .fixedLayout(width: 859, height: 669)) {
    NavigationStack {
        HomePage(dashboard: .preview, discoveries: .preview, isSideBySide: true) { _ in }
    }
}
