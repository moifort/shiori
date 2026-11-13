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
    /// What the hearted authors announced: "Prochaines sorties".
    @State private var releases: [UpcomingRelease] = []
    @State private var announced: DiscoveryVolume?
    @State private var awaited: AwaitedEdition?
    var news: NewsClient = .live

    init(client: AuthorsClient = .live, library: LibraryClient = .live, news: NewsClient = .live) {
        self.client = client
        self.library = library
        self.news = news
        _viewModel = State(initialValue: AuthorListViewModel(client: client))
    }

    var body: some View {
        PersonShelfPage(
            title: "Auteurs",
            failureTitle: "Auteurs indisponibles",
            noFavoritesTitle: "Aucun auteur préféré",
            noFavoritesMessage: "Touchez le cœur sur la page d’un auteur pour le retrouver ici.",
            rowIdentifier: "author-row",
            people: viewModel.people,
            order: viewModel.order,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            hasMore: viewModel.hasMore,
            loadMoreFailed: viewModel.loadMoreFailed,
            releases: releases,
            onOpenRelease: open,
            allTitle: "Tous les auteurs"
        ) { action in
            switch action {
            case let .openPerson(author): destination = .author(AuthorDestination(author))
            case let .openBook(book): destination = .book(book)
            case let .order(order): Task { await viewModel.show(order) }
            case let .menu(book, action): quick = BookQuickRequest(book: book, action: action)
            case let .reached(id): viewModel.prefetchIfNeeded(for: id)
            case .loadMore: Task { await viewModel.loadMore() }
            case .refresh: Task { await viewModel.load() }
            }
        }
        .scrollAwayBar(String(localized: "Auteurs"))
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .pushesDetail(item: $announced) { AnnouncedVolumeScreen(saga: $0.saga, volume: $0.volume) }
        .pushesDetail(item: $awaited) { AwaitedEditionScreen(edition: $0) {} }
        .task { await viewModel.loadOnAppear() }
        .task { await loadReleases() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
            Task { await loadReleases() }
        }
    }

    /// Everything announced, read off the release watches with no web lookup,
    /// kept to the hearted authors. A failure leaves the section as it was:
    /// it is gone when it has nothing to show.
    private func loadReleases() async {
        async let upcoming = news.upcoming()
        async let loved = client.list(200, nil, .loved)
        guard let upcoming = try? await upcoming, let loved = try? await loved else { return }
        let favorites = loved.items.filter(\.favorite).map(\.name)
        withAnimation { releases = FavoriteAuthorReleases.of(upcoming, favorites: favorites) }
    }

    /// Opens what the release opens in Actualités: the announced volume, the
    /// awaited edition, the author's page.
    private func open(_ release: UpcomingRelease) {
        Task {
            switch await UpcomingReleaseDestination.of(release) {
            case let .announced(volume): announced = volume
            case let .awaited(edition): awaited = edition
            case let .author(author): destination = .author(author)
            case .narrator, nil: break
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AuthorShelfScreen(client: .preview, library: .preview, news: .preview)
    }
}
#endif
