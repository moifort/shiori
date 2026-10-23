import SwiftUI

/// The search, connected: owns the view model and the shared index, and
/// pushes a book or a saga over the results.
/// Presented as a sheet from the Home and Library tabs.
struct LibrarySearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LibrarySearchViewModel
    @State private var selectedBook: Book?
    @State private var path: [SeriesHit] = []

    init(index: LibrarySearchIndex = .shared, client: LibrarySearchClient = .live) {
        _viewModel = State(initialValue: LibrarySearchViewModel(index: index, client: client))
    }

    var body: some View {
        NavigationStack(path: $path) {
            LibrarySearchPage(
                query: $viewModel.query,
                filter: viewModel.filter,
                results: viewModel.results,
                recentSearches: viewModel.recentSearches,
                recentlyViewed: viewModel.recentlyViewed,
                covers: viewModel.covers,
                isPreparing: viewModel.isPreparing,
                failed: viewModel.failed,
                isSearching: viewModel.isSearching
            ) { action in
                switch action {
                case let .openBook(book):
                    viewModel.opened()
                    selectedBook = book
                case let .openSeries(hit):
                    viewModel.opened()
                    path.append(hit)
                case .toggleFavorites: viewModel.toggleFavorites()
                case let .select(status): viewModel.select(status)
                case .clearFilter: viewModel.clearFilter()
                case let .useRecent(recent): viewModel.useRecent(recent)
                case .clearRecentSearches: viewModel.clearRecentSearches()
                case .retry: await viewModel.retry()
                case .close: dismiss()
                }
            }
            .navigationDestination(for: SeriesHit.self) { hit in
                SeriesScreen(seriesId: hit.id, language: hit.books.first?.language)
                    .closesAsPushed()
            }
            // Pushed over the results, as the saga is; closed, the book leads
            // the recently viewed.
            .pushesDetail(item: $selectedBook, onClose: { _ in viewModel.refreshViewed() }) { book in
                BookScreen(bookId: book.id)
            }
        }
        .task { await viewModel.appear() }
    }
}
