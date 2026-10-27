import SwiftUI

/// The narrators screen of the Library tab, connected as the authors' is:
/// `NarratorListViewModel` loads the narrators page by page in the order the
/// pills chose, this screen pushes a narrator or a book, and carries out the
/// long press.
struct NarratorShelfScreen: View {
    var client: NarratorsClient = .live
    var library: LibraryClient = .live

    @State private var viewModel: NarratorListViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?

    init(client: NarratorsClient = .live, library: LibraryClient = .live) {
        self.client = client
        self.library = library
        _viewModel = State(initialValue: NarratorListViewModel(client: client))
    }

    var body: some View {
        PersonShelfPage(
            title: "Narrateurs",
            failureTitle: "Narrateurs indisponibles",
            rowIdentifier: "narrator-row",
            people: viewModel.people,
            order: viewModel.order,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            hasMore: viewModel.hasMore,
            loadMoreFailed: viewModel.loadMoreFailed
        ) { action in
            switch action {
            case let .openPerson(narrator):
                destination = .narrator(NarratorDestination(key: narrator.key, name: narrator.name))
            case let .openBook(book): destination = .book(book)
            case let .order(order): Task { await viewModel.show(order) }
            case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
            case let .reached(id): viewModel.prefetchIfNeeded(for: id)
            case .loadMore: Task { await viewModel.loadMore() }
            case .refresh: Task { await viewModel.load() }
            }
        }
        .searchesLibrary(String(localized: "Narrateurs"))
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NarratorShelfScreen(client: .preview, library: .preview)
    }
}
#endif
