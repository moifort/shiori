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
    let onScan: () -> Void

    @State private var viewModel = HomeViewModel()
    @State private var selectedBook: Book?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Accueil")
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case let .series(id): SeriesView(seriesId: id)
                    }
                }
        }
        // Every time the tab comes back: a scan or an edit made in another tab
        // changes the figures, and the view behind them is one document read.
        .onAppear { Task { await viewModel.load() } }
        .sheet(item: $selectedBook) { book in
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
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
                    onReadingTapped: onShowReading,
                    onSeriesTapped: onShowSeries,
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
                Button("Réessayer") { Task { await viewModel.load() } }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
