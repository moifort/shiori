import SwiftUI

/// One shelf of the Library tab, connected: owns its view model, pushes the
/// books it opens, and carries out the long press. "Tous les livres" draws as
/// a mosaic, every other shelf as a grid of posters.
struct BookShelfScreen: View {
    let shelf: BookShelf
    var client: LibraryClient = .live

    @State private var viewModel: BookShelfViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?
    @State private var shareText: SharedText?
    @State private var isPreparingShare = false

    init(
        shelf: BookShelf,
        view: ShelvesView = ShelvesView(),
        status: ReadingStatus? = nil,
        formats: [BookFormat] = [],
        client: LibraryClient = .live
    ) {
        self.shelf = shelf
        self.client = client
        _viewModel = State(initialValue: BookShelfViewModel(
            client: client, shelf: shelf, view: view, status: status, formats: formats
        ))
    }

    var body: some View {
        Group {
            if shelf == .all {
                BookMosaicPage(
                    sections: viewModel.sections,
                    formats: viewModel.shownFormats,
                    selectedFormat: viewModel.query.view.format,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    hasMore: viewModel.hasMore,
                    loadMoreFailed: viewModel.loadMoreFailed,
                    onAction: handle
                )
            } else {
                BookShelfPage(
                    shelf: shelf,
                    sections: viewModel.sections,
                    lovedSeries: viewModel.lovedSeries,
                    statuses: viewModel.statusPills,
                    selectedStatus: viewModel.query.status,
                    genres: viewModel.genrePills,
                    selectedGenre: viewModel.query.view.genre,
                    formats: viewModel.shownFormats,
                    selectedFormat: viewModel.query.view.format,
                    isPreparingShare: isPreparingShare,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    hasMore: viewModel.hasMore,
                    loadMoreFailed: viewModel.loadMoreFailed,
                    onAction: handle
                )
            }
        }
        .searchesLibrary(shelf.title)
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: client) }
        .performsBookQuickActions($quick, client: client) { destination = $0 }
        .sheet(item: $shareText) { shared in
            ActivityView(text: shared.text)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
    }

    private func handle(_ action: BookShelfAction) {
        switch action {
        case let .openBook(book): destination = .book(book)
        case let .openSeries(saga): destination = .series(saga.seriesId)
        case let .selectStatus(status): viewModel.select(status: status)
        case let .selectGenre(genre): viewModel.select(genre: genre)
        case let .selectFormat(format): viewModel.select(format: format)
        case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
        case let .reached(id): viewModel.prefetchIfNeeded(for: id)
        case .loadMore: Task { await viewModel.loadMore() }
        case .refresh: Task { await viewModel.load() }
        case .share:
            isPreparingShare = true
            Task {
                if let text = await viewModel.shareMessage() { shareText = SharedText(text: text) }
                isPreparingShare = false
            }
        }
    }
}

/// A message on its way to the share sheet.
private struct SharedText: Identifiable {
    let id = UUID()
    let text: String
}

/// "Tous les livres", connected.
struct BookMosaicScreen: View {
    var view = ShelvesView()
    var formats: [BookFormat] = []
    var client: LibraryClient = .live

    var body: some View {
        BookShelfScreen(shelf: .all, view: view, formats: formats, client: client)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        BookShelfScreen(shelf: .recent, client: .preview)
    }
}
#endif
