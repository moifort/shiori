import SwiftUI

/// The Home tab: a dashboard of reading statistics and the shelves worth a glance.
///
/// Reading progress is still not tracked — keeping it truthful would mean asking
/// the reader for a page number every evening. The page figures spread each
/// finished book over the days it was open instead.
struct HomeView: View {
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

    @State private var viewModel = HomeViewModel()
    @State private var selectedBook: Book?
    @State private var showSettings = false
    /// The Audible and Kindle passes started at onboarding, still bringing the
    /// library in.
    @State private var audibleSync = AudibleBackgroundSync.shared
    @State private var kindleSync = KindleBackgroundSync.shared
    /// The wait onboarding hands over to, drawn in place of the dashboard.
    @State private var preparation = LibraryPreparation.shared
    /// The saga opened from its progress row, as a sheet like a book.
    @State private var openSeries: OpenedSeries?
    /// The volume announced opened from the releases, as Découvrir opens it.
    @State private var openRelease: DiscoveryVolume?
    /// The recording awaited opened from the releases, as Découvrir opens it.
    @State private var openAwaited: AwaitedEdition?
    /// The friend's favourite opened, on its read-only page.
    @State private var openFavorite: FriendFavorite?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Accueil")
                .toolbar {
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
        .sheet(item: $selectedBook) { book in
            // The book's own writes post the change notice this screen
            // reloads on: reloading here as well asked the server twice.
            BookView(bookId: book.id)
        }
        // An import or a sync asked for from the settings posts the change
        // notice as it lands: nothing is left to reload on dismissal.
        // A saga opened from the progress card was closed: its first opening
        // may have built the catalogue its bar is measured on, and reading a
        // catalogue is no write, so no notice says so.
        .sheet(item: $openSeries, onDismiss: { Task { await viewModel.load() } }) { opened in
            NavigationStack {
                SeriesView(seriesId: opened.id, isSheet: true)
            }
        }
        .sheet(item: $openRelease) { opened in
            NavigationStack {
                AnnouncedVolumeView(saga: opened.saga, volume: opened.volume)
            }
        }
        .sheet(item: $openFavorite) { favorite in
            if let book = favorite.openedBook {
                NavigationStack {
                    FriendBookView(
                        friendId: favorite.friendId,
                        bookId: book.id,
                        friendName: favorite.friendDisplayName
                    )
                }
            }
        }
        .sheet(item: $openAwaited) { edition in
            NavigationStack {
                AwaitedEditionView(edition: edition) {
                    Task {
                        do { try await AwaitedAPI.stop(id: edition.id) } catch { _ = reportError(error) }
                    }
                }
            }
        }
        // A recording awaited or given up comes into the releases, or leaves.
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.reloadReleases() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsHomeView()
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
                    onReadingTapped: { onShowLibrary(LibraryRequest(status: .reading)) },
                    onSeriesTapped: { onShowSeries(SeriesRequest(state: .inProgress)) },
                    onPileTapped: { onShowLibrary(LibraryRequest(status: .toRead)) },
                    onRatingTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onReadTapped: { onShowLibrary(LibraryRequest(status: .read)) },
                    onFavoritesTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onDroppedTapped: { onShowLibrary(LibraryRequest(status: .dropped)) },
                    onGenresTapped: { onShowLibrary(LibraryRequest()) },
                    onScan: onScan,
                    onBookTapped: { selectedBook = $0 },
                    onSeriesOpened: { openSeries = OpenedSeries(id: $0) },
                    onReleasesTapped: onShowDiscover,
                    onReleaseTapped: { release in
                        switch release {
                        case let .volume(volume): openRelease = volume
                        case let .awaited(edition): openAwaited = edition
                        }
                    },
                    onFriendFavoritesTapped: onShowShared,
                    onFriendFavoriteTapped: { openFavorite = $0 }
                )
                .refreshable { await viewModel.load() }
        } else if let errorMessage = viewModel.errorMessage {
            EmptyStateView.failure("Accueil indisponible", message: errorMessage) {
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
private struct OpenedSeries: Identifiable {
    let id: String
}
