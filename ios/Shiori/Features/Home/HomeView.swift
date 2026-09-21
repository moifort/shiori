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
    /// rating tile, the genres from the genre widget.
    let onShowLibrary: (LibraryMode) -> Void
    let onScan: () -> Void

    @State private var viewModel = HomeViewModel()
    @State private var selectedBook: Book?
    @State private var showSettings = false
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
                        ToolbarIconButton(title: "Réglages", systemImage: "gearshape") {
                            showSettings = true
                        }
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
            if dashboard.libraryIsEmpty {
                ContentUnavailableView {
                    Label("Votre bibliothèque est vide", systemImage: "books.vertical")
                } description: {
                    Text("Scannez la couverture d'un livre pour commencer. Vos statistiques de lecture apparaîtront ici.")
                } actions: {
                    Button("Scanner un livre", action: onScan)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home-scan")
                }
            } else {
                HomePage(
                    dashboard: dashboard,
                    isRefreshing: viewModel.isRefreshing,
                    refreshFailed: viewModel.refreshFailed,
                    onRetryRefresh: { await viewModel.refresh() },
                    onReadingTapped: onShowReading,
                    onSeriesTapped: onShowSeries,
                    onRatingTapped: { onShowLibrary(.favorites) },
                    onGenresTapped: { onShowLibrary(.genre) },
                    onBookTapped: { selectedBook = $0 }
                )
                .refreshable { await viewModel.load() }
            }
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Accueil indisponible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                AsyncButton("Réessayer") { await viewModel.load() }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
