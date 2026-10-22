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
    /// Opens Partagé, from the friends' favourites header.
    var onShowShared: () -> Void = {}

    @State private var viewModel: HomeViewModel
    /// What the dashboard opened: a sheet on a phone, the detail beside the
    /// dashboard on an unfolded iPhone Duo, as Mail shows a message beside
    /// its inbox.
    @State private var detail: HomeDetail?
    /// Regular on the Duo's inner screen, where a detail opens beside the
    /// dashboard rather than over it.
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showSettings = false
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

    init(
        onShowSeries: @escaping (SeriesRequest) -> Void,
        onShowLibrary: @escaping (LibraryRequest) -> Void,
        onScan: @escaping () -> Void,
        onShowDiscover: @escaping () -> Void = {},
        onShowShared: @escaping () -> Void = {},
        client: HomeClient = .live
    ) {
        self.onShowSeries = onShowSeries
        self.onShowLibrary = onShowLibrary
        self.onScan = onScan
        self.onShowDiscover = onShowDiscover
        self.onShowShared = onShowShared
        _viewModel = State(initialValue: HomeViewModel(client: client))
    }

    var body: some View {
        Group {
            if isSplit, let detail {
                // The dashboard stays in use on the left, the detail on the
                // right: the split view sets both columns, and moves them to
                // either side of the fold as the Duo folds.
                NavigationSplitView {
                    dashboard
                } detail: {
                    pane(detail)
                }
            } else {
                NavigationStack {
                    dashboard
                }
            }
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
        // On a phone, or a Duo folded, what the dashboard opens is a sheet.
        // Folding the Duo with a detail open beside the dashboard brings it
        // up as one; unfolding it puts the sheet back beside the dashboard.
        .sheet(item: sheetDetail) { detail in
            detailContent(detail)
        }
        // A recording awaited or given up comes into the releases, or leaves.
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.reloadReleases() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeScreen()
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
            .navigationTitle("Accueil")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSearch = true } label: {
                        Label("Rechercher", systemImage: "magnifyingglass")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("home-search")
                }
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
            // The first time only: after that, writes made anywhere
            // arrive through the change notice below.
            .task { await viewModel.loadOnAppear() }
    }

    /// Whether a detail opens beside the dashboard: the Duo's inner screen.
    private var isSplit: Bool { sizeClass == .regular }

    /// The detail as a sheet, while the screen is too narrow to set it beside
    /// the dashboard. The sheet a fold takes away hands its detail back to the
    /// split view rather than closing it.
    private var sheetDetail: Binding<HomeDetail?> {
        Binding(
            get: { isSplit ? nil : detail },
            set: { newValue in
                guard newValue == nil else { return detail = newValue }
                guard !isSplit, let closed = detail else { return }
                detail = nil
                afterClosing(closed)
            }
        )
    }

    /// The detail beside the dashboard, closed by its own button.
    private func pane(_ detail: HomeDetail) -> some View {
        detailContent(detail)
            .id(detail.id)
            .environment(\.closeDetailPane) {
                self.detail = nil
                afterClosing(detail)
            }
    }

    @ViewBuilder
    private func detailContent(_ detail: HomeDetail) -> some View {
        switch detail {
        case let .book(book):
            // The book's own writes post the change notice this screen
            // reloads on: reloading here as well asked the server twice.
            BookScreen(bookId: book.id)
        case let .series(id):
            NavigationStack {
                SeriesScreen(seriesId: id, isSheet: true)
            }
        case let .release(volume):
            NavigationStack {
                AnnouncedVolumeScreen(saga: volume.saga, volume: volume.volume)
            }
        case let .awaited(edition):
            NavigationStack {
                AwaitedEditionScreen(edition: edition) {
                    Task { await viewModel.stopAwaiting(edition) }
                }
            }
        case let .favorite(favorite):
            if let book = favorite.openedBook {
                NavigationStack {
                    FriendBookScreen(
                        friendId: favorite.friendId,
                        bookId: book.id,
                        friendName: favorite.friendDisplayName
                    )
                }
            }
        case let .discovery(suggestion):
            NavigationStack {
                SuggestionScreen(suggestion: suggestion) { outcome in
                    guard case let .dismissed(reason) = outcome else { return }
                    Task { await viewModel.dismiss(suggestion, reason: reason) }
                }
            }
        case .genres:
            NavigationStack { GenreInsightsScreen(load: viewModel.genreInsights) }
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
        case .book, .release, .awaited, .favorite, .genres: break
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
                    discoveries: viewModel.discoveries
                ) { action in
                    switch action {
                    case let .showLibrary(request): onShowLibrary(request)
                    case let .showSeries(request): onShowSeries(request)
                    case let .openSeries(id): detail = .series(id)
                    case let .openBook(book): detail = .book(book)
                    case .openGenres: detail = .genres
                    case .scan: onScan()
                    case .showDiscover: onShowDiscover()
                    case let .openRelease(.volume(volume)): detail = .release(volume)
                    case let .openRelease(.awaited(edition)): detail = .awaited(edition)
                    case .showShared: onShowShared()
                    case let .openFriendFavorite(favorite): detail = .favorite(favorite)
                    case let .openDiscovery(suggestion): detail = .discovery(suggestion)
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

/// A saga opened from the dashboard, by its catalogue id.
/// What the dashboard opens, as a sheet or beside it.
private enum HomeDetail: Identifiable {
    case book(Book)
    case series(String)
    case release(DiscoveryVolume)
    case awaited(AwaitedEdition)
    case favorite(FriendFavorite)
    case discovery(Suggestion)
    case genres

    var id: String {
        switch self {
        case let .book(book): "book-\(book.id)"
        case let .series(id): "series-\(id)"
        case let .release(volume): "release-\(volume.id)"
        case let .awaited(edition): "awaited-\(edition.id)"
        case let .favorite(favorite): "favorite-\(favorite.id)"
        case let .discovery(suggestion): "discovery-\(suggestion.id)"
        case .genres: "genres"
        }
    }
}
