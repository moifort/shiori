import SwiftUI

/// "Pile à lire", connected: owns its view model, pushes the books and the
/// sagas it opens, and carries out the long press.
struct PileScreen: View {
    var client: LibraryClient = .live

    @State private var viewModel: PileViewModel
    /// The series screen's own model, for its "Séries à continuer": opened on the
    /// same snapshot, refreshed with the pile.
    @State private var series: SeriesShelfViewModel
    @State private var destination: LibraryDestination?
    @State private var quick: BookQuickRequest?
    @State private var volume: DiscoveryVolume?
    @State private var wish: Wish?
    @State private var edition: AwaitedEdition?

    init(view: ShelvesView = ShelvesView(), client: LibraryClient = .live, seriesClient: SeriesClient = .live) {
        self.client = client
        _viewModel = State(initialValue: PileViewModel(client: client, view: view))
        _series = State(initialValue: SeriesShelfViewModel(client: seriesClient))
    }

    var body: some View {
        PilePage(
            pile: viewModel.pile,
            wished: viewModel.wished.map { .init(book: $0, caption: viewModel.wishlist.caption(of: $0)) },
            upNext: series.upNext.filter(viewModel.view.keeps),
            genres: viewModel.shownGenres,
            selectedGenre: viewModel.view.genre,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onAction: handle
        )
        .scrollAwayBar(BookShelf.toRead.title)
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: client) }
        .performsBookQuickActions($quick, client: client) { destination = $0 }
        .pushesDetail(item: $volume) { AnnouncedVolumeScreen(saga: $0.saga, volume: $0.volume) }
        .pushesDetail(item: $wish) { WishScreen(wish: $0) }
        .pushesDetail(item: $edition) { AwaitedEditionScreen(edition: $0) }
        .task { await viewModel.loadOnAppear() }
        .task { await series.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
            Task { await series.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriWishlistDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .alert(
            "Action impossible",
            isPresented: .init(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    private func handle(_ action: PileAction) {
        switch action {
        case let .openBook(book): destination = .book(book)
        case let .openSeries(saga): destination = .series(saga.seriesId)
        case let .openVolume(volume): self.volume = volume
        case let .selectGenre(genre): Task { await viewModel.select(genre: genre) }
        case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
        case .openWishlist: destination = .wishlist
        case let .dropWished(book): Task { await viewModel.dropWished(book) }
        case let .openWished(book):
            if let wished = viewModel.wishlist.wish(for: book) {
                wish = wished
            } else if let awaited = viewModel.wishlist.edition(for: book) {
                edition = awaited
            }
        case .refresh:
            Task { await viewModel.load() }
            Task { await series.load() }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PileScreen(client: .preview, seriesClient: .preview)
    }
}
#endif
