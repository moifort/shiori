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

    /// Opens the Library tab on the books being read.
    let onShowReading: () -> Void
    let onShowSeries: () -> Void
    /// Opens the Library tab on one of its views: the favourites from the
    /// rating and favourites tiles, the genres from the genre widget, the
    /// dropped books from their tile.
    let onShowLibrary: (LibraryRequest) -> Void
    let onScan: () -> Void

    @State private var viewModel = HomeViewModel()
    @State private var selectedBook: Book?
    @State private var showSettings = false
    /// An Audible pass started at onboarding, still bringing the library in.
    @State private var audibleSync = AudibleBackgroundSync.shared
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
                        // While an Audible import runs in the background, the
                        // gear turns into a spinning sync icon: the one sign
                        // that more books are on their way.
                        Button { showSettings = true } label: {
                            if audibleSync.isSyncing {
                                Label("Import Audible en cours", systemImage: "arrow.triangle.2.circlepath")
                                    .symbolEffect(.rotate, options: .repeat(.continuous))
                            } else {
                                Label("Réglages", systemImage: "gearshape")
                            }
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
        }
        // Every time the tab comes back: a scan or an edit made in another tab
        // changes the figures, and the view behind them is one document read.
        .onAppear { Task { await viewModel.loadOnAppear() } }
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
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
        }
        // Reloaded on dismissal: an import or a sync asked for from the settings
        // moves the figures behind this sheet, a hundred books at a time.
        .sheet(isPresented: $showSettings, onDismiss: { Task { await viewModel.load() } }) {
            SettingsHomeView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let dashboard = viewModel.dashboard {
            // Drawn even for an empty library: every card sketches what it will
            // hold, and the scan prompt leads the page until the first book.
            HomePage(
                    dashboard: dashboard,
                    isRefreshing: viewModel.isRefreshing,
                    refreshFailed: viewModel.refreshFailed,
                    onRetryRefresh: { await viewModel.refresh() },
                    onReadingTapped: onShowReading,
                    onSeriesTapped: onShowSeries,
                    onRatingTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onFavoritesTapped: { onShowLibrary(LibraryRequest(mode: .favorites)) },
                    onDroppedTapped: { onShowLibrary(LibraryRequest(status: .dropped)) },
                    onGenresTapped: { onShowLibrary(LibraryRequest(mode: .genre)) },
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
