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
    /// What the hearted narrators recorded and is announced: "Prochaines
    /// sorties", opened on last session's snapshot and brought up to date
    /// underneath.
    @State private var releases: [UpcomingRelease]
    var news: NewsClient = .live

    init(client: NarratorsClient = .live, library: LibraryClient = .live, news: NewsClient = .live) {
        self.client = client
        self.library = library
        self.news = news
        _viewModel = State(initialValue: NarratorListViewModel(client: client))
        let cached = Self.releasesCache.read() ?? []
        _releases = State(initialValue: FavoriteAuthorReleases.stillAhead(cached))
    }

    /// The section's last rows on disk, so the shelf opens on them. Bump the
    /// version whenever `UpcomingRelease` changes shape.
    private static let releasesCache = SnapshotCache<[UpcomingRelease]>("narrator-releases", version: 1)

    var body: some View {
        PersonShelfPage(
            title: "Narrateurs",
            failureTitle: "Narrateurs indisponibles",
            noFavoritesTitle: "Aucun narrateur préféré",
            noFavoritesMessage: "Touchez le cœur sur la page d’un narrateur pour le retrouver ici.",
            rowIdentifier: "narrator-row",
            people: viewModel.people,
            order: viewModel.order,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            hasMore: viewModel.hasMore,
            loadMoreFailed: viewModel.loadMoreFailed,
            releases: releases,
            onOpenRelease: open,
            allTitle: "Tous les narrateurs"
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
        .scrollAwayBar(String(localized: "Narrateurs"))
        .pushesDetail(item: $destination) { LibraryDestinationScreen(destination: $0, client: library) }
        .performsBookQuickActions($quick, client: library) { destination = $0 }
        .task { await viewModel.loadOnAppear() }
        .task { await loadReleases() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
            Task { await loadReleases() }
        }
    }

    /// Everything announced, read off the release watches with no web lookup,
    /// kept to the hearted narrators' recordings. A failure leaves the section
    /// as it was: it is gone when it has nothing to show.
    private func loadReleases() async {
        guard let upcoming = try? await news.upcoming() else { return }
        let fresh = FavoriteNarratorReleases.of(upcoming)
        guard fresh != releases else { return }
        withAnimation(releases.isEmpty ? nil : .smooth) { releases = fresh }
        let cache = Self.releasesCache
        Task.detached { cache.write(fresh) }
    }

    /// Opens what the release opens in Actualités: a recording on its narrator.
    private func open(_ release: UpcomingRelease) {
        Task {
            switch await UpcomingReleaseDestination.of(release) {
            case let .narrator(narrator): destination = .narrator(narrator)
            case let .author(author): destination = .author(author)
            case .announced, .awaited, nil: break
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NarratorShelfScreen(client: .preview, library: .preview, news: .preview)
    }
}
#endif
