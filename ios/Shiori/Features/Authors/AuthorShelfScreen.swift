import SwiftUI

/// The authors screen of the Library tab, connected: `AuthorListViewModel`
/// loads the authors page by page in the order the pills chose, this screen
/// pushes an author or a book, and carries out the long press.
struct AuthorShelfScreen: View {
    var client: AuthorsClient = .live
    var library: LibraryClient = .live

    @State private var viewModel: AuthorListViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?

    init(client: AuthorsClient = .live, library: LibraryClient = .live) {
        self.client = client
        self.library = library
        _viewModel = State(initialValue: AuthorListViewModel(client: client))
    }

    var body: some View {
        AuthorShelfPage(
            authors: viewModel.authors,
            order: viewModel.order,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            hasMore: viewModel.hasMore,
            loadMoreFailed: viewModel.loadMoreFailed
        ) { action in
            switch action {
            case let .openAuthor(author): destination = .author(AuthorDestination(author))
            case let .openBook(book): destination = .book(book)
            case let .order(order): Task { await viewModel.show(order) }
            case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
            case let .reached(id): viewModel.prefetchIfNeeded(for: id)
            case .loadMore: Task { await viewModel.loadMore() }
            case .refresh: Task { await viewModel.load() }
            }
        }
        .searchesLibrary()
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
    }
}

#Preview {
    NavigationStack {
        AuthorShelfScreen(client: .preview, library: .preview)
    }
}
