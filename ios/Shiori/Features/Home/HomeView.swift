import SwiftUI

/// The Home tab: a dashboard of reading statistics and the shelves worth a glance.
///
/// Reading progress is still not tracked — keeping it truthful would mean asking
/// the reader for a page number every evening. The page figures spread each
/// finished book over the days it was open instead.
struct HomeView: View {
    enum Destination: Hashable {
        case series(String)
    }

    /// Opens the Series tab on one of its views: the sagas in progress from
    /// the progress card.
    let onShowSeries: (SeriesRequest) -> Void
    /// Opens the Library tab on one of its views: every card and tile of the
    /// dashboard leads to the list it counts — the books being read, the pile,
    /// the rated books, the favourites, the dropped ones, the whole shelf.
    let onShowLibrary: (LibraryRequest) -> Void
    let onScan: () -> Void

    @State private var viewModel = HomeViewModel()
    @State private var selectedBook: Book?
    @State private var showSettings = false
    /// An Audible pass started at onboarding, still bringing the library in.
    @State private var audibleSync = AudibleBackgroundSync.shared
    /// The wait onboarding hands over to, drawn in place of the dashboard.
    @State private var preparation = LibraryPreparation.shared
    /// The stack behind the dashboard: a saga is pushed onto it from its
    /// progress row.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
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
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case let .series(id): SeriesView(seriesId: id)
                    }
                }
                // The first time only: after that, writes made anywhere
                // arrive through the change notice below.
                .task { await viewModel.loadOnAppear() }
        }
        // A saga pushed from the progress card was popped: its first opening
        // may have built the catalogue its bar is measured on, and reading a
        // catalogue is no write, so no notice says so.
        .onChange(of: path.count) { previous, current in
            if current < previous { Task { await viewModel.load() } }
        }
        // And every time a write lands anywhere: the figures behind this screen
        // are rebuilt by the server on each one, and the tab may be showing.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .alert(
            "Import Audible interrompu",
            isPresented: Binding(
                get: { audibleSync.errorMessage != nil },
                set: { if !$0 { audibleSync.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { audibleSync.errorMessage = nil }
        } message: {
            Text("\(audibleSync.errorMessage ?? "") Vous pouvez relancer la synchronisation depuis les réglages.")
        }
        .sheet(item: $selectedBook) { book in
            // The book's own writes post the change notice this screen
            // reloads on: reloading here as well asked the server twice.
            BookView(bookId: book.id)
        }
        // An import or a sync asked for from the settings posts the change
        // notice as it lands: nothing is left to reload on dismissal.
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
                    // An Audible pass that outlasted the preparation screen is
                    // still bringing books in: the leading spinner says so.
                    isRefreshing: viewModel.isRefreshing || audibleSync.isSyncing,
                    refreshFailed: viewModel.refreshFailed,
                    onRetryRefresh: { await viewModel.refresh() },
                    onReadingTapped: { onShowLibrary(LibraryRequest(status: .reading)) },
                    onSeriesTapped: { onShowSeries(SeriesRequest(state: .inProgress)) },
                    onPileTapped: { onShowLibrary(LibraryRequest(status: .toRead)) },
                    onRatingTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onReadTapped: { onShowLibrary(LibraryRequest(status: .read)) },
                    onFavoritesTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onDroppedTapped: { onShowLibrary(LibraryRequest(status: .dropped)) },
                    onGenresTapped: { onShowLibrary(LibraryRequest()) },
                    onScan: onScan,
                    onBookTapped: { selectedBook = $0 }
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
}
