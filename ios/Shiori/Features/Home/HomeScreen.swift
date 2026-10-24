import SwiftUI

/// The Home tab: a dashboard of reading statistics and the shelves worth a glance.
///
/// Reading progress is still not tracked — keeping it truthful would mean asking
/// the reader for a page number every evening. The page figures spread each
/// finished book over the days it was open instead.
struct HomeScreen: View {
    /// Opens the Series tab on one of its views: the sagas in progress from
    /// the progress card.
    let onShowSeries: (SeriesRequest) -> Void
    /// Opens the Library tab on one of its views: every card and tile of the
    /// dashboard leads to the list it counts — the books being read, the pile,
    /// the rated books, the favourites, the dropped ones, the whole shelf.
    let onShowLibrary: (LibraryRequest) -> Void
    let onScan: () -> Void
    /// Opens Découvrir, from the releases header.
    var onShowDiscover: () -> Void = {}

    @State private var viewModel: HomeViewModel
    /// What the dashboard opened: pushed over it on a phone, beside it on an
    /// unfolded iPhone Duo, as Mail shows a message beside its inbox.
    @State private var detail: HomeDetail?
    /// Regular on the Duo's inner screen, where a detail opens beside the
    /// dashboard rather than over it.
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showSettings = false
    /// The book read now, rated from its card on the page.
    @State private var ratedBook: Book?
    /// The search over the reader's books, from the loupe in the corner.
    @State private var showSearch = false
    /// The month's costs and readers, behind a toolbar button only an admin
    /// account sees.
    @State private var showAdmin = false
    @Environment(\.isAdmin) private var isAdmin
    /// The Audible and Kindle passes started at onboarding, still bringing the
    /// library in.
    @State private var audibleSync = AudibleBackgroundSync.shared
    @State private var kindleSync = KindleBackgroundSync.shared
    /// The wait onboarding hands over to, drawn in place of the dashboard.
    @State private var preparation = LibraryPreparation.shared
    /// Whether the discoveries' carousel has been scrolled off the top: the
    /// bar stays empty over it until then, as in the TV app.
    @State private var carouselScrolledAway = false

    init(
        onShowSeries: @escaping (SeriesRequest) -> Void,
        onShowLibrary: @escaping (LibraryRequest) -> Void,
        onScan: @escaping () -> Void,
        onShowDiscover: @escaping () -> Void = {},
        client: HomeClient = .live
    ) {
        self.onShowSeries = onShowSeries
        self.onShowLibrary = onShowLibrary
        self.onScan = onScan
        self.onShowDiscover = onShowDiscover
        _viewModel = State(initialValue: HomeViewModel(client: client))
    }

    var body: some View {
        // What the dashboard opens sits beside it on an unfolded Duo, as Mail
        // sets a message beside its inbox, and is pushed over it on a phone.
        DetailSplit(item: $detail, onClose: afterClosing) {
            dashboard
        } detail: { detail in
            detailContent(detail)
        }
        // And every time a write lands anywhere: the figures behind this screen
        // are rebuilt by the server on each one, and the tab may be showing.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        // One alert for both passes: two on one view would shadow each other.
        // Audible's is said first, Kindle's on the next appearance.
        .alert(
            audibleSync.errorMessage != nil ? "Import Audible interrompu" : "Import Kindle interrompu",
            isPresented: Binding(
                get: { audibleSync.errorMessage != nil || kindleSync.errorMessage != nil },
                set: { if !$0 { dismissSyncError() } }
            )
        ) {
            Button("OK", role: .cancel) { dismissSyncError() }
        } message: {
            Text("\(audibleSync.errorMessage ?? kindleSync.errorMessage ?? "") Vous pouvez relancer la synchronisation depuis les réglages.")
        }
        .sheet(isPresented: $showSearch) {
            LibrarySearchScreen()
        }
        // A recording awaited or given up comes into the releases, or leaves.
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.reloadReleases() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeScreen()
        }
        .sheet(item: $ratedBook) { book in
            RatingPromptSheet(current: book.rating) { stars in
                ratedBook = nil
                Task { await viewModel.rate(book, stars: stars) }
            }
        }
        .alert(
            "Une erreur est survenue",
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .sheet(isPresented: $showAdmin) {
            NavigationStack {
                AdminScreen()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                                showAdmin = false
                            }
                        }
                    }
            }
        }
    }

    /// The dashboard, its toolbar and its first load: the root of the stack
    /// on a phone, the leading column beside a detail on an unfolded Duo.
    private var dashboard: some View {
        content
            // The hero names the page, with the day: the bar keeps the title
            // for VoiceOver and the Back button, and draws none of its own.
            .navigationTitle("Accueil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text(verbatim: "").accessibilityHidden(true) }
                if showsCarousel {
                    // Over the carousel the bar is empty; scrolled, it names
                    // the page on the left and holds the buttons on the right.
                    if carouselScrolledAway {
                        ToolbarItem(placement: .topBarLeading) {
                            Text("Accueil")
                                .font(.title2.weight(.bold))
                                .fixedSize()
                                .accessibilityHidden(true)
                        }
                        .sharedBackgroundVisibility(.hidden)
                        ToolbarItem(placement: .topBarTrailing) { searchButton }
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        trailingButtons
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) { searchButton }
                    trailingButtons
                }
            }
            // Nothing for the bar's blur to sit under while it is empty.
            .scrollEdgeEffectHidden(showsCarousel && !carouselScrolledAway, for: .top)
            // The first time only: after that, writes made anywhere
            // arrive through the change notice below.
            .task { await viewModel.loadOnAppear() }
    }

    private var searchButton: some View {
        Button { showSearch = true } label: {
            Label("Rechercher", systemImage: "magnifyingglass")
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("home-search")
    }

    @ToolbarContentBuilder
    private var trailingButtons: some ToolbarContent {
        if isAdmin {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIconButton(title: "Admin", systemImage: "shield") {
                    showAdmin = true
                }
                .accessibilityIdentifier("home-admin")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            // The settings hold the account, the subscription and the
            // connected sources: managing a linked Audible account is
            // a setting, not an import, and lives there.
            Button { showSettings = true } label: {
                Label("Réglages", systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("home-settings")
        }
    }

    /// Whether the page opens on the discoveries' carousel: on a phone or the
    /// folded Duo, once the month's choice is ready.
    private var showsCarousel: Bool {
        !isSplit && !preparation.isActive && viewModel.dashboard != nil
            && !(viewModel.discoveries?.shownOnHome.isEmpty ?? true)
    }

    /// Whether a detail opens beside the dashboard: the Duo's inner screen.
    private var isSplit: Bool { sizeClass == .regular }

    @ViewBuilder
    private func detailContent(_ detail: HomeDetail) -> some View {
        switch detail {
        case let .book(book):
            // The book's own writes post the change notice this screen
            // reloads on: reloading here as well asked the server twice.
            BookScreen(bookId: book.id)
        case let .series(id):
            SeriesScreen(seriesId: id)
        case let .release(volume):
            AnnouncedVolumeScreen(saga: volume.saga, volume: volume.volume)
        case let .awaited(edition):
            AwaitedEditionScreen(edition: edition) {
                Task { await viewModel.stopAwaiting(edition) }
            }
        case let .favorite(favorite):
            if let book = favorite.openedBook {
                FriendBookScreen(
                    friendId: favorite.friendId,
                    bookId: book.id,
                    friendName: favorite.friendDisplayName
                )
            }
        case let .discovery(suggestion):
            SuggestionScreen(suggestion: suggestion) { outcome in
                guard case let .dismissed(reason) = outcome else { return }
                Task { await viewModel.dismiss(suggestion, reason: reason) }
            }
        case .genres:
            GenreInsightsScreen(load: viewModel.genreInsights)
        case .statistics:
            HomeStatisticsScreen(
                dashboard: viewModel.dashboard,
                onShowLibrary: onShowLibrary,
                genreInsights: viewModel.genreInsights
            )
        }
    }

    /// What a closed detail leaves to refresh. A saga's first opening may have
    /// built the catalogue its bar is measured on, and reading a catalogue is
    /// no write, so no notice says so. A discovery closed is asked again: an
    /// addition, a wait or a dismissal takes the book off, and the next one
    /// comes in.
    private func afterClosing(_ detail: HomeDetail) {
        switch detail {
        case .series: Task { await viewModel.load() }
        case .discovery: Task { await viewModel.loadDiscoveries() }
        case .book, .release, .awaited, .favorite, .genres, .statistics: break
        }
    }

    @ViewBuilder
    private var content: some View {
        if preparation.isActive {
            LibraryPreparationView { await viewModel.load() }
                .transition(.opacity)
        } else if let dashboard = viewModel.dashboard {
            // Drawn even for an empty library: every card sketches what it will
            // hold, and the scan prompt leads the page until the first book.
            HomePage(
                    dashboard: dashboard,
                    releases: viewModel.releases,
                    friendFavorites: viewModel.friendFavorites,
                    discoveries: viewModel.discoveries,
                    isSideBySide: isSplit && detail == nil,
                    isCompact: !isSplit,
                    onCarouselScrolledAway: { scrolledAway in
                        guard scrolledAway != carouselScrolledAway else { return }
                        withAnimation(.smooth(duration: 0.25)) { carouselScrolledAway = scrolledAway }
                    }
                ) { action in
                    switch action {
                    case let .showLibrary(request): onShowLibrary(request)
                    case let .showSeries(request): onShowSeries(request)
                    case let .openSeries(id): detail = .series(id)
                    case let .openBook(book): detail = .book(book)
                    case .openGenres: detail = .genres
                    case .showStatistics: detail = .statistics
                    case let .finishBook(book): Task { await viewModel.finish(book) }
                    case let .rateBook(book): ratedBook = book
                    case .scan: onScan()
                    case .showDiscover: onShowDiscover()
                    case let .openRelease(.volume(volume)): detail = .release(volume)
                    case let .openRelease(.awaited(edition)): detail = .awaited(edition)
                    case let .openFriendFavorite(favorite): detail = .favorite(favorite)
                    case let .openDiscovery(suggestion): detail = .discovery(suggestion)
                    case let .addDiscovery(suggestion, status):
                        Task {
                            await SuggestionViewModel(suggestion: suggestion, client: .live).add(status: status)
                            await viewModel.loadDiscoveries()
                        }
                    case let .awaitDiscovery(suggestion, format):
                        Task {
                            await SuggestionViewModel(suggestion: suggestion, client: .live).awaitEdition(format)
                            await viewModel.loadDiscoveries()
                        }
                    }
                }
                .refreshable { await viewModel.load() }
        } else if let errorMessage = viewModel.errorMessage {
            EmptyState.failure("Accueil indisponible", message: errorMessage) {
                await viewModel.load()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Clears the pass whose failure was just said: Audible's first, as the
    /// alert shows it first.
    private func dismissSyncError() {
        if audibleSync.errorMessage != nil {
            audibleSync.errorMessage = nil
        } else {
            kindleSync.errorMessage = nil
        }
    }
}

/// What the dashboard opens, pushed over it or beside it.
private enum HomeDetail: Identifiable {
    case book(Book)
    case series(String)
    case release(DiscoveryVolume)
    case awaited(AwaitedEdition)
    case favorite(FriendFavorite)
    case discovery(Suggestion)
    case genres
    case statistics

    var id: String {
        switch self {
        case let .book(book): "book-\(book.id)"
        case let .series(id): "series-\(id)"
        case let .release(volume): "release-\(volume.id)"
        case let .awaited(edition): "awaited-\(edition.id)"
        case let .favorite(favorite): "favorite-\(favorite.id)"
        case let .discovery(suggestion): "discovery-\(suggestion.id)"
        case .genres: "genres"
        case .statistics: "statistics"
        }
    }
}

/// The statistics, from the line of figures under the home screen's hero: the
/// dashboard's figures in full, the genre card opening the genres read, the
/// last book finished opening its page, both pushed on the statistics' stack.
private struct HomeStatisticsScreen: View {
    let dashboard: Dashboard?
    let onShowLibrary: (LibraryRequest) -> Void
    let genreInsights: () async throws -> GenreInsights

    @State private var genres: GenresDestination?
    @State private var openedBook: Book?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    var body: some View {
        Group {
            if let dashboard {
                StatisticsPage(dashboard: dashboard) { action in
                    switch action {
                    case let .showLibrary(request): onShowLibrary(request)
                    case .openGenres: genres = GenresDestination()
                    case let .openBook(book): openedBook = book
                    default: break
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        closing.close(dismissPresentation)
                    }
                }
            }
        }
        .pushesDetail(item: $genres) { _ in
            GenreInsightsScreen(load: genreInsights)
        }
        .pushesDetail(item: $openedBook) { book in
            BookScreen(bookId: book.id)
        }
    }

    private struct GenresDestination: Identifiable {
        var id: String { "genres" }
    }
}
