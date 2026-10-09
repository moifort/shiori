import SwiftUI

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
/// Above everything, "Coups de cœur de vos amis": what the friends hearted and
/// the reader holds in no format, as a strip that scrolls sideways so it takes
/// one row — covers on the Books shelf, sagas on the Series shelf, faces on the
/// Authors shelf, the newest heart first. A flame marks what many of them love.
///
/// Under them, on the Books shelf, "Bientôt disponible": the books the reader
/// awaits in the app's language, translated or recorded, as one strip of
/// covers — the ones announced first, then the ones out, then the ones not
/// announced yet, the latest awaited first. Then "Prix littéraires": the latest
/// winners of the awards of the genre the reader reads most that they do not
/// hold, a strip of covers with every award in full behind "Tout voir". Then
/// "Nouveautés séries": the volumes out in the last two weeks the reader can
/// have now, the newest first, then the ones announced, the soonest first.
///
/// The server looks the sagas up on the web once a week. The tab opens on
/// everything it last showed — the rows, the friends' picks, the books awaited
/// — brought up to date silently underneath, as the Series tab is. On the very
/// first look at a format, when nothing followed in it was ever looked up, it
/// is all looked up at once behind a full-screen message; a saga or an author
/// followed since waits for the hourly pass.
struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var openSeries: SagaDiscovery?
    /// The volume whose page is open, announced or just out.
    @State private var openVolume: DiscoveryVolume?
    @State private var openAuthor: AuthorDestination?
    @State private var openFriendBook: LovedBook?
    @State private var openFriendSaga: LovedSaga?
    @State private var openAwaited: AwaitedEdition?
    @State private var openWinner: AwardWinner?
    @State private var openAwards: AwardShelf?
    @Environment(\.openURL) private var openURL
    /// Held by `ContentView`, which brings it back to the books on each visit.
    @Binding var shelf: LibraryShelf

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        DiscoverAlertsButton()
                    }
                }
                .libraryShelfPicker($shelf, shelves: [.books, .series, .authors])
                // A sheet, as a book opens from the library.
                .sheet(item: $openSeries) { row in
                    NavigationStack {
                        SeriesView(
                            seriesId: row.series.seriesId,
                            language: row.series.language,
                            isSheet: true
                        )
                    }
                }
                .sheet(item: $openVolume) { opened in
                    NavigationStack {
                        AnnouncedVolumeView(saga: opened.saga, volume: opened.volume)
                    }
                }
                .sheet(item: $openFriendBook) { loved in
                    NavigationStack {
                        FriendBookView(
                            friendId: loved.lovers.first?.userId ?? "",
                            bookId: loved.book.id,
                            friendName: loved.lovers.first?.displayName ?? ""
                        )
                    }
                }
                // The reader holds no volume of it: the saga is named to the
                // server, which catalogues it if nobody has yet.
                .sheet(item: $openFriendSaga) { loved in
                    NavigationStack {
                        SeriesView(
                            seriesId: loved.saga.seriesId,
                            language: loved.saga.language,
                            isSheet: true,
                            proposal: loved.saga.author.map { SeriesProposal(name: loved.saga.name, author: $0) }
                        )
                    }
                }
                .sheet(item: $openAwaited) { edition in
                    NavigationStack {
                        AwaitedEditionView(edition: edition) {
                            Task { await viewModel.stopAwaiting(edition) }
                        }
                    }
                }
                .sheet(item: $openWinner) { winner in
                    NavigationStack { AwardWinnerView(winner: winner) }
                }
                .sheet(item: $openAwards) { awards in
                    NavigationStack { AwardsListView(format: viewModel.awardsFormat, shelf: awards) }
                }
                // The Library's own author page, in its own stack so a saga
                // pushes inside it.
                .sheet(item: $openAuthor) { opened in
                    NavigationStack {
                        AuthorView(key: opened.key, name: opened.name, isSheet: true, isOffered: opened.isOffered)
                    }
                }
        }
        .task { await viewModel.loadOnAppear() }
        .task { await viewModel.loadPicks() }
        .task {
            for format in ReleaseFormat.allCases { await viewModel.loadAwaited(format) }
        }
        // The format follows what the reader holds, known once the rows are in.
        .task(id: viewModel.awardsFormat) { await viewModel.loadAwards(viewModel.awardsFormat) }
        // The Authors shelf carries the editions awaited too.
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task {
                await viewModel.reloadAwaited()
                await viewModel.reload()
                await viewModel.loadAwards(viewModel.awardsFormat)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task {
                await viewModel.reload()
                await viewModel.loadPicks()
                await viewModel.loadAwards(viewModel.awardsFormat)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLookingUp {
            // The first look: everything followed is being looked up on the
            // web, and there is nothing to show until it is.
            DiscoverFirstLookView()
                .accessibilityIdentifier("discover-looking-up")
        } else if viewModel.rows != nil {
            list
        } else if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
            EmptyStateView.failure("Découvrir indisponible", message: errorMessage) {
                await viewModel.loadAll()
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var list: some View {
        List {
            friendPicksSection
            if shelf == .books {
                awaitedSection
                awardsSection
            }
            if shelf == .authors {
                authorSections
            } else {
                sagaSections
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            async let picks: Void = viewModel.loadPicks()
            await viewModel.loadAll()
            await picks
        }
    }

    /// "Coups de cœur de vos amis", in the shape of the shelf on screen. Absent
    /// when the friends love nothing the reader does not hold.
    @ViewBuilder
    private var friendPicksSection: some View {
        let picks = viewModel.picks
        let isEmpty = switch shelf {
        case .books: picks.books.isEmpty
        case .series: picks.sagas.isEmpty
        case .authors: picks.authors.isEmpty
        }
        if !isEmpty {
            Section {
                switch shelf {
                case .books:
                    LovedBooksStrip(books: picks.books) { openFriendBook = $0 }
                case .series:
                    LovedSagasStrip(sagas: picks.sagas) { openFriendSaga = $0 }
                case .authors:
                    LovedAuthorsStrip(authors: picks.authors) {
                        openAuthor = AuthorDestination(key: $0.key, name: $0.name, isOffered: true)
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
        let picks = viewModel.picks
        switch shelf {
        case .books:
            let awards = viewModel.awards[viewModel.awardsFormat]?.recent ?? []
            return picks.books.isEmpty && viewModel.awaitedSoon.isEmpty && awards.isEmpty
        case .series: return picks.sagas.isEmpty
        case .authors: return picks.authors.isEmpty
        }
    }

    /// "Bientôt disponible": the editions the reader awaits, translated and
    /// recorded in one strip like the friends' favourites, the headphones on a
    /// recording's cover. Absent when nothing is awaited.
    @ViewBuilder
    private var awaitedSection: some View {
        let editions = viewModel.awaitedSoon
        if !editions.isEmpty {
            Section {
                AwaitedEditionsStrip(editions: editions) { openAwaited = $0 }
            } header: {
                Text("Bientôt disponible")
            }
            .accessibilityIdentifier("discover-awaited")
        }
    }

    /// "Prix littéraires": the latest winners of the awards of the genre the
    /// reader reads most, the ones they do not hold — in print, or recorded
    /// for a reader who only listens — as a strip like the editions awaited. "Tout voir" opens every award in
    /// full. Absent when the reader reads no genre with awards enough.
    @ViewBuilder
    private var awardsSection: some View {
        if let awards = viewModel.awards[viewModel.awardsFormat], !awards.recent.isEmpty {
            Section {
                AwardWinnersStrip(winners: awards.recent) { openWinner = $0 }
            } header: {
                HStack {
                    Text("Prix littéraires · \(awards.genre.label)")
                    Spacer()
                    Button("Tout voir") { openAwards = awards }
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                        .accessibilityIdentifier("discover-awards-all")
                }
            }
            .accessibilityIdentifier("discover-awards")
        }
    }

    /// The Books and Series shelves: the sagas' volumes just out, then the
    /// ones announced, read and heard mixed. The Books shelf lists them as one
    /// section, "Nouveautés séries"; the Series shelf, where one saga may be in
    /// both, keeps them apart.
    @ViewBuilder
    private var sagaSections: some View {
        let upcoming = viewModel.upcoming
        let recentVolumes = viewModel.recentVolumes
        let recentSagas = viewModel.recentSagas
        if upcoming.isEmpty && recentSagas.isEmpty {
            if isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "sparkles",
                    title: "Rien de neuf pour l'instant",
                        message: "Les nouveautés et les prochains tomes annoncés de vos séries apparaîtront ici."
                    )
                }
                .listRowBackground(Color.clear)
            }
        } else if shelf == .books {
            let coming = upcoming.compactMap { saga in
                saga.releases.next.map { DiscoveryVolume(saga: saga, volume: $0) }
            }
            Section {
                SeriesNewsStrip(
                    volumes: recentVolumes + coming,
                    onTapped: { openVolume = $0 },
                    onOpenSeries: { openSeries = $0 }
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
        let upcoming = viewModel.upcomingAuthors
        let recent = viewModel.recentAuthors
        if upcoming.isEmpty && recent.isEmpty && isEmpty {
            Section {
                EmptyStateView(
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
    /// in words. A
    /// long press opens one of those volumes. A tap opens the author's page, as the Library's Authors
    /// shelf does.
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
                .onTapGesture { openAuthor = destination }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openAuthor = destination }
            AuthorWorksStrip(items: items, author: row.author.name)
            AuthorReleasesSummary(items: items, section: section)
        }
        .contextMenu {
            ForEach(works.map(\.work).filter { $0.audibleURL != nil }, id: \.title) { work in
                if let audibleURL = work.audibleURL {
                    Button("Ouvrir « \(work.title) » dans Audible", systemImage: "headphones") {
                        openURL(audibleURL)
                    }
                }
            }
            ForEach(volumes) { opened in
                Button("Ouvrir « \(opened.volume.title) »", systemImage: "book") { openVolume = opened }
            }
            Button("Ouvrir l'auteur", systemImage: "person") { openAuthor = destination }
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
                .onTapGesture { openSeries = row }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openSeries = row }
            SagaReleasesSummary(releases: row.releases, missing: row.missing, section: section)
        }
        .contextMenu {
            Button("Ouvrir la série", systemImage: "books.vertical") { openSeries = row }
        }
        .accessibilityIdentifier("discover-series-row")
    }

}

/// What a saga has for the reader, in a line under its covers, as the section
/// it is in says: among the new releases, the volumes out they have not added
/// yet; among the announcements, the next volume — its date already hangs
/// under its cover.
struct SagaReleasesSummary: View {
    enum Section { case recent, upcoming }

    let releases: SagaReleases
    let missing: [Int]
    let section: Section

    var body: some View {
        if let line = section == .recent ? availablePart : comingPart {
            Text(verbatim: line)
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
        }
    }

    private var comingPart: String? {
        releases.next.map { String(localized: "À venir : Tome \($0.number)") }
    }

    private var availablePart: String? {
        guard !missing.isEmpty else { return nil }
        let numbers = missing.map(String.init).joined(separator: ", ")
        return String(localized: "Disponible : Tome \(numbers)")
    }
}

/// What an author has for the reader, in a line under their covers, as the
/// section they are in says: among the new releases, the newest book out;
/// among the announcements, the next one and its date. One title only: a few
/// side by side would not fit.
struct AuthorReleasesSummary: View {
    let items: [AuthorNewsItem]
    let section: SagaReleasesSummary.Section

    var body: some View {
        if let line {
            Text(verbatim: line)
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
    }

    private var line: String? {
        guard let first = items.first else { return nil }
        switch section {
        case .upcoming:
            guard let date = first.date else { return String(localized: "À venir : \(first.title)") }
            return String(localized: "À venir : \(first.title) · \(ReleaseDateText.short(date))")
        case .recent:
            return String(localized: "Disponible : \(first.title)")
        }
    }
}

extension AuthorDiscovery {
    /// Matt Dinniman on the Authors shelf heard: a work of his own announced,
    /// an edition followed, and the next volume of his saga the Books shelf
    /// lists, just out and announced.
    static let preview: AuthorDiscovery = {
        var saga = SagaDiscovery.preview
        saga.recent = [DiscoveredVolume(
            number: 7,
            title: "La Parade de Mondes",
            date: "2026-09-24",
            isbn13: nil,
            coverURL: nil
        )]
        return AuthorDiscovery(
            author: FollowedAuthor(
                key: "matt-dinniman",
                name: "Matt Dinniman",
                indexLetter: "D",
                portraitURL: nil,
                bookCount: 7,
                seriesCount: 1,
                favoriteCount: 1,
                averageRating: 4.5,
                shelvedAt: nil,
                books: []
            ),
            next: DiscoveredWork(
                title: "Kaiju Battlefield Surgeon",
                date: "2027-02-16",
                isbn13: nil,
                coverURL: nil,
                seriesName: nil,
                volume: nil
            ),
            recent: [],
            awaited: [.preview],
            sagas: [saga]
        )
    }()
}

#Preview {
    DiscoverView(shelf: .constant(.books))
}

/// "Nouveautés séries": the volumes of the sagas followed, read and heard, as
/// a strip of covers like the editions awaited — the ones just out first with
/// their day in green, then the ones announced with theirs in orange. A tap
/// opens the volume's page; a long press offers its saga, and a recording's
/// page on Audible.
struct SeriesNewsStrip: View {
    let volumes: [DiscoveryVolume]
    let onTapped: (DiscoveryVolume) -> Void
    let onOpenSeries: (SagaDiscovery) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(volumes) { opened in
                    Button { onTapped(opened) } label: {
                        CoverTile(
                            book: opened.cover,
                            caption: opened.caption,
                            showsTitle: false,
                            captionTint: opened.isComing ? .orange : .green
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let audibleURL = opened.volume.audibleURL {
                            Button("Ouvrir dans Audible", systemImage: "headphones") { openURL(audibleURL) }
                        }
                        Button("Ouvrir la série", systemImage: "books.vertical") { onOpenSeries(opened.saga) }
                    }
                    .accessibilityIdentifier("discover-volume-row")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

extension DiscoveryVolume {
    /// Still to come: announced for a day not reached, or for none yet.
    var isComing: Bool {
        volume.date.map { ReleaseDateText.isUpcoming($0) } ?? true
    }

    /// Under its cover: the day it comes or came out, or that it is announced.
    var caption: String {
        volume.date.map(ReleaseDateText.short) ?? String(localized: "Annoncé")
    }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover.
    var cover: Book {
        let series = saga.series
        return Book(
            id: "release-\(series.id)-\(volume.number)",
            title: volume.title,
            authors: series.author.map { [$0] } ?? [],
            format: series.isAudio ? .audiobook : .book,
            language: series.language,
            coverURL: volume.coverURL,
            status: .toRead
        )
    }
}
