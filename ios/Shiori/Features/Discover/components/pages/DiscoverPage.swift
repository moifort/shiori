import SwiftUI

/// Everything Découvrir's page can ask for.
enum DiscoverAction {
    case openSeries(SagaDiscovery)
    case openVolume(DiscoveryVolume)
    case openAuthor(AuthorDestination)
    case openFriendBook(LovedBook)
    case openFriendSaga(LovedSaga)
    case openAwaited(AwaitedEdition)
    case openWinner(AwardWinner)
    case openSuggestion(Suggestion)
    case openAlerts
    /// A pull: the friends' picks and both formats asked again.
    case refresh
    /// The failure's button, over an empty tab.
    case retry
}

/// The Découvrir tab: every saga the reader follows — all but the ones they
/// set aside — with the next volume announced they do not hold, the soonest
/// first. The volumes already out are not listed: the saga screen shows them
/// under "Tomes", with the button that adds them.
///
/// Read and heard together: no format to pick, every section mixes the sagas
/// read and the sagas heard, the headphones on a recording's cover telling
/// them apart.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// capsule above the tab bar switches between "Livres" — each volume drawn as
/// the Books tab draws a book, a tap opening its page described on the spot —
/// and "Séries" — the Series tab's rows, every cover of their strip; a tap
/// opens the saga screen as a sheet — and "Auteurs" — the Authors shelf's
/// rows, one per author whatever the formats they are followed in, for the
/// authors the reader holds with a book announced or just out, an edition of
/// theirs they follow that is announced or out, or a volume of one of their
/// sagas the Books shelf lists; a tap opens the author's page as the Library
/// opens it.
///
/// On the Series and Authors shelves, above everything, "Coups de cœur de vos
/// amis": what the friends hearted and the reader holds in no format, as a
/// strip that scrolls sideways so it takes one row — sagas on the Series
/// shelf, faces on the Authors shelf, the newest heart first. A flame marks
/// what many of them love.
///
/// The Books shelf is read at a glance rather than scrolled: one card, a
/// line per category over a strip of its covers — "Bientôt disponible", the
/// books the reader awaits in the app's language, translated or recorded;
/// "Prix littéraires", the latest winners of the genres they read most that
/// they do not hold; the friends' hearts. Every cover is there, a tap opening
/// its page. Under the card, "Nouveautés séries": the sagas' volumes just
/// out, then announced.
///
/// On the very first look at a format, when nothing followed in it was ever
/// looked up, it is all looked up at once behind a full-screen message.
struct DiscoverPage: View {
    /// Held by `ContentView`, which brings it back to the books on each visit.
    @Binding var shelf: LibraryShelf
    let feed: DiscoveryFeed
    /// The award winners of the format shown.
    let awards: [AwardSection]
    let discoveries: DiscoveriesLine?
    /// The first look: everything followed is being looked up on the web.
    let isLookingUp: Bool
    let isLoading: Bool
    let errorMessage: String?
    let alertsSilenced: Bool
    let onAction: (DiscoverAction) async -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        content
            .navigationTitle("Découvrir")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DiscoverAlertsButton(isSilenced: alertsSilenced) { act(.openAlerts) }
                }
            }
            .libraryShelfPicker($shelf, shelves: [.books, .series, .authors])
    }

    /// A tap that only opens something: nothing to wait for.
    private func act(_ action: DiscoverAction) {
        Task { await onAction(action) }
    }

    @ViewBuilder
    private var content: some View {
        if isLookingUp {
            // The first look: everything followed is being looked up on the
            // web, and there is nothing to show until it is.
            FirstLookProgress()
                .accessibilityIdentifier("discover-looking-up")
        } else if feed.sagas != nil {
            list
        } else if let errorMessage, !isLoading {
            EmptyState.failure("Découvrir indisponible", message: errorMessage) {
                await onAction(.retry)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var list: some View {
        List {
            if shelf == .books {
                summarySection
            } else {
                friendPicksSection
            }
            if shelf == .authors {
                authorSections
            } else {
                sagaSections
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await onAction(.refresh) }
    }

    /// "Coups de cœur de vos amis", in the shape of the shelf on screen. Absent
    /// when the friends love nothing the reader does not hold.
    @ViewBuilder
    private var friendPicksSection: some View {
        let picks = feed.picks
        let isEmpty = switch shelf {
        case .books: picks.books.isEmpty
        case .series: picks.sagas.isEmpty
        case .authors: picks.authors.isEmpty
        }
        if !isEmpty {
            Section {
                switch shelf {
                case .books:
                    LovedBooksStrip(books: picks.books) { act(.openFriendBook($0)) }
                case .series:
                    LovedSagasStrip(sagas: picks.sagas) { act(.openFriendSaga($0)) }
                case .authors:
                    LovedAuthorsStrip(authors: picks.authors) {
                        act(.openAuthor(AuthorDestination(key: $0.key, name: $0.name, isOffered: true)))
                    }
                }
            } header: {
                Text("Coups de cœur de vos amis")
            }
            .accessibilityIdentifier("discover-friend-picks")
        }
    }

    /// Whether the shelf on screen shows nothing above its news either: the
    /// friends love nothing new, and on the Books shelf nothing is awaited and
    /// no award winner is offered. Only then does the empty news say so — under
    /// other sections it would read as a page with nothing on it.
    private var isEmpty: Bool {
        let picks = feed.picks
        switch shelf {
        case .books: return picks.books.isEmpty && feed.awaitedSoon.isEmpty && awards.isEmpty
        case .series: return picks.sagas.isEmpty
        case .authors: return picks.authors.isEmpty
        }
    }

    /// The Books shelf at a glance: one line per category that holds
    /// something — the editions awaited, the award winners of the genres read
    /// most, the latest prize first whatever its genre, the friends' hearts,
    /// the newest first — each over a strip of every cover it holds, a tap
    /// opening its page. Absent when all three are empty; the sagas' news has
    /// its own strip under it.
    @ViewBuilder
    private var summarySection: some View {
        let width = CoverTile.summaryWidth
        let awaited = feed.awaitedSoon
        // The newest heart first, as the server sends them; the flame alone
        // marks what many friends love.
        let loved = feed.picks.books
        if !awaited.isEmpty || discoveries != nil || !awards.isEmpty || !loved.isEmpty {
            Section {
                if !awaited.isEmpty {
                    DiscoverSummaryRow(
                        category: .soon,
                        line: DiscoverSummaryLine.soon(awaited)
                    ) {
                        ForEach(awaited) { edition in
                            AwaitedEditionTile(edition: edition, width: width) { act(.openAwaited(edition)) }
                        }
                    }
                    .accessibilityIdentifier("discover-awaited")
                }
                if let discoveries {
                    DiscoveriesSummaryRow(line: discoveries, width: width) { act(.openSuggestion($0)) }
                }
                if !awards.isEmpty {
                    DiscoverSummaryRow(
                        category: .awards,
                        line: DiscoverSummaryLine.awards(awards)
                    ) {
                        ForEach(awards.flatMap(\.winners).latestFirst) { winner in
                            AwardWinnerTile(winner: winner, width: width) { act(.openWinner(winner)) }
                        }
                    }
                    .accessibilityIdentifier("discover-awards")
                }
                if !loved.isEmpty {
                    DiscoverSummaryRow(
                        category: .friends,
                        line: DiscoverSummaryLine.friends(loved)
                    ) {
                        ForEach(loved) { picked in
                            LovedBookTile(loved: picked, width: width) { act(.openFriendBook(picked)) }
                        }
                    }
                    .accessibilityIdentifier("discover-friend-picks")
                }
            }
        }
    }

    /// The Books and Series shelves: the sagas' volumes just out, then the
    /// ones announced, read and heard mixed. The Books shelf lists them as one
    /// section, "Nouveautés séries"; the Series shelf, where one saga may be in
    /// both, keeps them apart.
    @ViewBuilder
    private var sagaSections: some View {
        let upcoming = feed.upcoming
        let recentSagas = feed.recentSagas
        if upcoming.isEmpty && recentSagas.isEmpty {
            if isEmpty {
                Section {
                    EmptyState(
                        systemImage: "sparkles",
                        title: "Rien de neuf pour l'instant",
                        message: "Les nouveautés et les prochains tomes annoncés de vos séries apparaîtront ici."
                    )
                }
                .listRowBackground(Color.clear)
            }
        } else if shelf == .books {
            Section {
                SeriesNewsStrip(
                    volumes: feed.seriesNews,
                    onTapped: { act(.openVolume($0)) },
                    onOpenSeries: { act(.openSeries($0)) }
                )
            } header: {
                Text("Nouveautés séries")
            }
            .accessibilityIdentifier("discover-series-news")
        } else {
            if !recentSagas.isEmpty {
                Section {
                    ForEach(recentSagas) { row($0, in: .recent) }
                } header: {
                    Text("Nouvelles parutions")
                }
                .accessibilityIdentifier("discover-recent")
            }
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { row($0, in: .upcoming) }
                } header: {
                    Text("Prochaines sorties")
                }
            }
        }
    }

    /// The Authors shelf: the authors with a book just out, then the ones with
    /// a book announced, each drawn as the Library's Authors shelf draws them.
    @ViewBuilder
    private var authorSections: some View {
        let upcoming = feed.upcomingAuthors
        let recent = feed.recentAuthors
        if upcoming.isEmpty && recent.isEmpty && isEmpty {
            Section {
                EmptyState(
                    systemImage: "person.2",
                    title: "Rien de neuf pour l'instant",
                    message: "Les nouveautés et les prochains livres annoncés de vos auteurs apparaîtront ici."
                )
            }
            .listRowBackground(Color.clear)
        }
        if !recent.isEmpty {
            Section {
                ForEach(recent) { authorRow($0, in: .recent) }
            } header: {
                Text("Nouvelles parutions")
            }
        }
        if !upcoming.isEmpty {
            Section {
                ForEach(upcoming) { authorRow($0, in: .upcoming) }
            } header: {
                Text("Prochaines sorties")
            }
        }
    }

    /// An author's row: the Authors shelf's heading, then the covers of what
    /// the section it is in is about rather than the reader's own books — the
    /// works the web found, the editions the reader awaits and the volumes of
    /// their sagas the Books shelf lists alike, read and heard — and the first
    /// in words. A long press opens one of those volumes. A tap opens the
    /// author's page, as the Library's Authors shelf does.
    private func authorRow(_ row: AuthorNews, in section: SagaReleasesSummary.Section) -> some View {
        let destination = AuthorDestination(row.author)
        let works = row.works(in: section)
        let volumes = row.volumes(in: section)
        let items = AuthorNewsItem.ordered(
            works: works,
            awaited: row.awaited(in: section),
            volumes: volumes,
            section: section
        )
        return VStack(alignment: .leading, spacing: 8) {
            AuthorRow(author: row.author, showsBooks: false)
                .contentShape(Rectangle())
                // A tap rather than a button: a button would claim the drag
                // that scrolls the cover strip.
                .onTapGesture { act(.openAuthor(destination)) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { act(.openAuthor(destination)) }
            AuthorWorksStrip(items: items, author: row.author.name)
            AuthorReleasesSummary(items: items, section: section)
        }
        .contextMenu {
            ForEach(works.map(\.work).filter { $0.audibleURL != nil }, id: \.title) { work in
                if let audibleURL = work.audibleURL {
                    Button(work.title, systemImage: "headphones") {
                        openURL(audibleURL)
                    }
                }
            }
            ForEach(volumes) { opened in
                Button(opened.volume.title, systemImage: "book") { act(.openVolume(opened)) }
            }
            Button("Auteur", systemImage: "person") { act(.openAuthor(destination)) }
        }
        .accessibilityIdentifier("discover-author-row")
    }

    /// A saga's row: the Series tab's own, every cover of its strip, and
    /// underneath what the section it is in is about — the volumes out it has
    /// among the new releases, the next one among the announcements.
    private func row(_ row: SagaDiscovery, in section: SagaReleasesSummary.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SeriesRow(entry: row.series)
                .contentShape(Rectangle())
                // A tap rather than a button: a button would claim the drag
                // that scrolls the cover strip.
                .onTapGesture { act(.openSeries(row)) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { act(.openSeries(row)) }
            SagaReleasesSummary(releases: row.releases, missing: row.missing, section: section)
        }
        .contextMenu {
            Button("Série", systemImage: "books.vertical") { act(.openSeries(row)) }
        }
        .accessibilityIdentifier("discover-series-row")
    }
}

private struct DiscoverPagePreview: View {
    @State var shelf: LibraryShelf
    var feed = DiscoveryFeed.preview
    var awards = AwardSection.previews
    var discoveries: DiscoveriesLine? = .shown(.preview)
    var isLookingUp = false
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        NavigationStack {
            DiscoverPage(
                shelf: $shelf,
                feed: feed,
                awards: awards,
                discoveries: discoveries,
                isLookingUp: isLookingUp,
                isLoading: isLoading,
                errorMessage: errorMessage,
                alertsSilenced: false
            ) { _ in }
        }
    }
}

#Preview("Books") { DiscoverPagePreview(shelf: .books) }
#Preview("Series") { DiscoverPagePreview(shelf: .series) }
#Preview("Authors") { DiscoverPagePreview(shelf: .authors) }
#Preview("Empty") {
    DiscoverPagePreview(
        shelf: .books,
        feed: DiscoveryFeed(rows: [.book: []], followed: [.book: 0]),
        awards: [],
        discoveries: nil
    )
}
#Preview("Loading") { DiscoverPagePreview(shelf: .books, feed: DiscoveryFeed(), isLoading: true) }
#Preview("Failed") {
    DiscoverPagePreview(shelf: .books, feed: DiscoveryFeed(), errorMessage: "La connexion a été perdue.")
}
#Preview("First look") { DiscoverPagePreview(shelf: .books, isLookingUp: true) }
