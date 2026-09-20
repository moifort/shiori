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
    /// The import source whose card is open. One source today; the menu is here so
    /// the next one is an entry rather than a redesign.
    @State private var openSource: ImportSource?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Accueil")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // A menu rather than a button, because managing a
                        // connected library is not the same act as importing from
                        // it, and the next source lands here too.
                        Menu {
                            ForEach(ImportSource.allCases) { source in
                                Button {
                                    openSource = source
                                } label: {
                                    Label(source.label, systemImage: source.symbol)
                                }
                            }
                        } label: {
                            Label("Imports", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("home-imports")
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
        .onAppear { Task { await viewModel.load() } }
        .sheet(item: $selectedBook) { book in
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
        }
        // Reloaded on dismissal rather than on the import's callback: a pass asked
        // for on the card catalogues books without ever importing anything through
        // the picker, and the figures behind this sheet have moved either way.
        // An import can add a hundred books across a dozen sagas, so the dashboard
        // is rebuilt rather than patched figure by figure.
        .sheet(item: $openSource, onDismiss: { Task { await viewModel.load() } }) { source in
            switch source {
            case .audible:
                AudibleImportView(onImported: { _ in openSource = nil })
            }
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
