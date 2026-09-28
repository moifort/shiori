import SwiftUI

/// The Découvrir tab: every saga the reader follows — all but the ones they
/// set aside — with the next volume announced they do not hold, the soonest
/// first. The volumes already out are not listed: the saga screen shows them
/// under "Tomes", with the button that adds them.
///
/// Laid out as the Library tab is, so nothing here has to be learnt twice: the
/// capsule above the tab bar switches between "Livres" — each volume announced
/// drawn as the Books tab draws a book, the soonest out first, a tap opening
/// its page described on the spot — and "Séries" — the Series tab's rows, every
/// cover of their strip; a tap opens the saga screen as a sheet — and
/// "Auteurs" — the Authors shelf's rows, for the authors the reader holds with
/// a book announced or just out outside the sagas they hold; a tap opens the
/// author's page as the Library opens it. Read through one format at a time —
/// the saga read or the saga heard — picked in the toolbar and kept between
/// visits: an author is watched only in the formats the reader holds them in.
///
/// Above what is announced, "Nouvelles parutions": the volumes out in the last
/// week the reader can have now, read off the same weekly look.
///
/// Above everything, "Coups de cœur de vos amis": what the friends hearted and
/// the reader holds in no format, as a strip that scrolls sideways so it takes
/// one row — covers on the Books shelf, sagas on the Series shelf, faces on the
/// Authors shelf, the newest heart first. A flame marks what many of them love.
///
/// Under them, on the Books shelf, "Bientôt en audio" or "Bientôt en FR": the
/// books the reader awaits in the app's language, in the format on screen, as
/// a strip of covers, the ones out first — "Voir les livres guettés" opens the
/// whole list, where a swipe gives one up.
///
/// The server looks the sagas up on the web once a week. The tab opens on the
/// rows it last showed, brought up to date silently underneath. On the very
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
    @State private var showAwaitedList = false
    /// The edition opened from the full list, pushed inside it.
    @State private var openListedAwaited: AwaitedEdition?
    @Environment(\.openURL) private var openURL
    @State private var format: ReleaseFormat = .book
    @State private var shelf: LibraryShelf = .series
    /// The format was picked this session — by a tap, or once for the reader —
    /// and is kept even when it holds no saga.
    @State private var formatSettled = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Découvrir")
                .toolbar { toolbar }
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
                .sheet(item: $openFriendSaga) { loved in
                    NavigationStack {
                        SeriesView(
                            seriesId: loved.saga.seriesId,
                            language: loved.saga.language,
                            isSheet: true
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
                .sheet(isPresented: $showAwaitedList) {
                    NavigationStack {
                        AwaitedEditionsListView(
                            format: format,
                            editions: viewModel.awaited(format),
                            onOpen: { openListedAwaited = $0 },
                            onStop: { edition in Task { await viewModel.stopAwaiting(edition) } }
                        )
                        .navigationDestination(item: $openListedAwaited) { edition in
                            AwaitedEditionView(edition: edition) {
                                Task { await viewModel.stopAwaiting(edition) }
                            }
                        }
                    }
                }
                // The Library's own author page, in its own stack so a saga
                // pushes inside it.
                .sheet(item: $openAuthor) { opened in
                    NavigationStack {
                        AuthorView(key: opened.key, name: opened.name, isSheet: true)
                    }
                }
        }
        .task(id: format) {
            await viewModel.loadOnAppear(format)
            openOnAFollowedFormat()
        }
        .task { await viewModel.loadPicks() }
        .task(id: format) { await viewModel.loadAwaited(format) }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.reloadAwaited() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task {
                await viewModel.reload()
                await viewModel.loadPicks()
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
        } else if let rows = viewModel.rows(format) {
            list(rows)
        } else if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
            EmptyStateView.failure("Découvrir indisponible", message: errorMessage) {
                await viewModel.load(format)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func list(_ rows: [SagaDiscovery]) -> some View {
        List {
            // The snapshot on screen is brought up to date silently. Only a
            // refresh that failed says so, since the rows are then last time's.
            if viewModel.refreshFailed {
                RefreshRow(
                    failed: viewModel.refreshFailed,
                    loadingLabel: "Mise à jour de Découvrir",
                    onRetry: { await viewModel.refresh(format) }
                )
            }
            friendPicksSection
            if shelf == .books { awaitedSection }
            if shelf == .authors {
                authorSections
            } else {
                sagaSections(rows)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            async let picks: Void = viewModel.loadPicks()
            await viewModel.load(format)
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
                        openAuthor = AuthorDestination(key: $0.key, name: $0.name)
                    }
                }
            } header: {
                Text("Coups de cœur de vos amis")
            }
            .accessibilityIdentifier("discover-friend-picks")
        }
    }

    /// "Bientôt en audio" or "Bientôt en FR": the editions the reader awaits in
    /// the format on screen, as a strip like the friends' favourites, and the
    /// way to the full list. Absent when none is awaited.
    @ViewBuilder
    private var awaitedSection: some View {
        let editions = viewModel.awaited(format)
        if !editions.isEmpty {
            Section {
                AwaitedEditionsStrip(editions: editions) { openAwaited = $0 }
            } header: {
                HStack {
                    Text(format.awaitedTitle)
                    Spacer()
                    Button("Voir les livres guettés") { showAwaitedList = true }
                        .font(.subheadline)
                        .textCase(nil)
                        .accessibilityIdentifier("discover-awaited-all")
                }
            }
            .accessibilityIdentifier("discover-awaited")
        }
    }

    /// The Books and Series shelves: the sagas' volumes just out, then the
    /// ones announced.
    @ViewBuilder
    private func sagaSections(_ rows: [SagaDiscovery]) -> some View {
        let upcoming = shelf == .books
            ? viewModel.upcoming(format) ?? []
            : rows.filter { $0.releases.next != nil }
        let recentVolumes = viewModel.recentVolumes(format) ?? []
        let recentSagas = viewModel.recentSagas(format) ?? []
        if upcoming.isEmpty && recentSagas.isEmpty {
            Section {
                EmptyStateView(
                    systemImage: format == .audiobook ? "headphones" : "sparkles",
                    title: "Rien de neuf pour l'instant",
                    message: format == .audiobook
                        ? "Les nouveautés et les prochains tomes annoncés de vos séries audio apparaîtront ici."
                        : "Les nouveautés et les prochains tomes annoncés de vos séries apparaîtront ici."
                )
            }
            .listRowBackground(Color.clear)
        }
        if !recentSagas.isEmpty {
            Section {
                if shelf == .books {
                    ForEach(recentVolumes) { volumeRow($0) }
                } else {
                    ForEach(recentSagas) { row($0, in: .recent) }
                }
            } header: {
                Text("Nouvelles parutions")
            }
            .accessibilityIdentifier("discover-recent")
        }
        if !upcoming.isEmpty {
            Section {
                ForEach(upcoming) { saga in
                    if shelf == .books {
                        if let next = saga.releases.next {
                            volumeRow(DiscoveryVolume(saga: saga, volume: next))
                        }
                    } else {
                        row(saga, in: .upcoming)
                    }
                }
            } header: {
                Text("Prochaines sorties")
            }
        }
    }

    /// The Authors shelf: the authors with a book just out, then the ones with
    /// a book announced, each drawn as the Library's Authors shelf draws them.
    @ViewBuilder
    private var authorSections: some View {
        let upcoming = viewModel.upcomingAuthors(format) ?? []
        let recent = viewModel.recentAuthors(format) ?? []
        if upcoming.isEmpty && recent.isEmpty {
            Section {
                EmptyStateView(
                    systemImage: format == .audiobook ? "headphones" : "person.2",
                    title: "Rien de neuf pour l'instant",
                    message: format == .audiobook
                        ? "Les nouveautés et les prochains livres audio annoncés de vos auteurs apparaîtront ici."
                        : "Les nouveautés et les prochains livres annoncés de vos auteurs apparaîtront ici."
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
    /// the section it is in is about rather than the reader's own books, and
    /// the newest in words. A tap opens the author's page, as the Library's
    /// Authors shelf does.
    private func authorRow(_ row: AuthorDiscovery, in section: SagaReleasesSummary.Section) -> some View {
        let destination = AuthorDestination(row.author)
        let works = section == .recent ? row.recent : (row.next.map { [$0] } ?? [])
        return VStack(alignment: .leading, spacing: 8) {
            AuthorRow(author: row.author, showsBooks: false)
                .contentShape(Rectangle())
                // A tap rather than a button: a button would claim the drag
                // that scrolls the cover strip.
                .onTapGesture { openAuthor = destination }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { openAuthor = destination }
            AuthorWorksStrip(works: works, author: row.author.name, isAudio: format == .audiobook)
            AuthorReleasesSummary(works: works, section: section)
        }
        .contextMenu {
            ForEach(works.filter { $0.audibleURL != nil }) { work in
                if let audibleURL = work.audibleURL {
                    Button("Ouvrir « \(work.title) » dans Audible", systemImage: "headphones") {
                        openURL(audibleURL)
                    }
                }
            }
            Button("Ouvrir l'auteur", systemImage: "person") { openAuthor = destination }
        }
        .accessibilityIdentifier("discover-author-row")
    }

    /// A volume announced or just out, drawn as the Books tab draws a book: its
    /// saga as a tag, the headphones on the cover of a recording, and on the
    /// trailing edge the day it comes or came out. No genre: the saga already
    /// says what it is.
    ///
    /// A tap opens the volume's page, described on the spot for a scan; a long
    /// press offers its saga, and a recording's page on Audible.
    private func volumeRow(_ opened: DiscoveryVolume) -> some View {
        let saga = opened.saga
        let volume = opened.volume
        let series = saga.series
        let membership = SeriesMembership(
            id: series.seriesId,
            name: series.name,
            volume: volume.number,
            kind: .main
        )
        return BookRow(
            title: volume.title,
            authorLine: series.author ?? "",
            cover: Book(
                id: "release-\(series.id)-\(volume.number)",
                title: volume.title,
                authors: series.author.map { [$0] } ?? [],
                format: series.isAudio ? .audiobook : .book,
                genre: series.genre,
                language: series.language,
                series: membership,
                coverURL: volume.coverURL,
                status: .toRead
            ),
            status: .toRead,
            rating: nil,
            series: membership,
            language: series.language,
            releaseDate: volume.date
        )
        .contentShape(Rectangle())
        .onTapGesture { openVolume = opened }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openVolume = opened }
        .contextMenu {
            if let audibleURL = volume.audibleURL {
                Button("Ouvrir dans Audible", systemImage: "headphones") { openURL(audibleURL) }
            }
            Button("Ouvrir la série", systemImage: "books.vertical") { openSeries = saga }
        }
        .accessibilityIdentifier("discover-volume-row")
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

    /// A reader who follows no saga in the format on screen — every saga of
    /// theirs heard, say — sees the other one instead, once a session: a
    /// format they tapped stays, and two empty formats do not bounce.
    private func openOnAFollowedFormat() {
        guard !formatSettled, viewModel.followed(format) == 0, viewModel.awaited(format).isEmpty
        else { return }
        formatSettled = true
        format = ReleaseFormat.allCases.first { $0 != format } ?? format
    }

    /// The two formats where the Library and Series tabs keep their views: icons
    /// on the right, the one picked in the tint.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            DiscoverAlertsButton()
        }
        ToolbarItemGroup {
            ForEach(ReleaseFormat.allCases) { item in
                Button {
                    formatSettled = true
                    format = item
                } label: {
                    Label(item.filterLabel, systemImage: item.symbol)
                }
                .labelStyle(.iconOnly)
                .tint(format == item ? .accentColor : .primary)
                .accessibilityIdentifier("discover-format-\(item.rawValue)")
            }
        }
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
    let works: [DiscoveredWork]
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
        guard let first = works.first else { return nil }
        switch section {
        case .upcoming:
            guard let date = first.date else { return String(localized: "À venir : \(first.title)") }
            return String(localized: "À venir : \(first.title) · \(ReleaseDateText.short(date))")
        case .recent:
            return String(localized: "Disponible : \(first.title)")
        }
    }
}

#Preview {
    DiscoverView()
}
