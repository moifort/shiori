import SwiftUI

/// The Authors shelf, connected: `AuthorListViewModel` loads the authors page
/// by page, this screen opens one as a sheet and reloads what changed, and
/// `AuthorListPage` draws them.
struct AuthorListScreen: View {
    /// Opens the add sheet, from the one button every empty state offers.
    var onScan: () -> Void = {}
    /// The shelf capsule of the Library tab, drawn under the list.
    var shelf: Binding<LibraryShelf>? = nil
    var client: AuthorsClient = .live

    @State private var viewModel: AuthorListViewModel
    /// The author being opened. A tap and a destination rather than a
    /// navigation link, as on the Series tab: a link would claim the drag that
    /// scrolls the covers, and draw a chevron on every row.
    @State private var openAuthor: AuthorDestination?

    init(onScan: @escaping () -> Void = {}, shelf: Binding<LibraryShelf>? = nil, client: AuthorsClient = .live) {
        self.onScan = onScan
        self.shelf = shelf
        self.client = client
        _viewModel = State(initialValue: AuthorListViewModel(client: client))
    }

    var body: some View {
        // An author is pushed over the list on a phone, and set beside it on an
        // unfolded iPhone Duo; a saga pushes after it.
        DetailSplit(item: $openAuthor) {
            AuthorListPage(
                authors: viewModel.authors,
                order: viewModel.order,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                hasMore: viewModel.hasMore,
                loadMoreFailed: viewModel.loadMoreFailed
            ) { action in
                switch action {
                case let .open(author): openAuthor = AuthorDestination(author)
                case let .order(order): await viewModel.show(order)
                case let .reached(id): viewModel.prefetchIfNeeded(for: id)
                case .loadMore: await viewModel.loadMore()
                case .refresh: await viewModel.load()
                case .scan: onScan()
                }
            }
            .libraryShelfPicker(shelf)
            // Over last session's snapshot when the disk had one: the rows show
            // at once and are brought up to date underneath.
            .task { await viewModel.loadOnAppear() }
        } detail: { opened in
            AuthorScreen(key: opened.key, name: opened.name, client: client)
        }
        // A book finished, a heart given, a book scanned: the rows here say so
        // the next time the reader looks — all of them, so the reader stays
        // where they were, and a loved author climbs into place.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
        // An author's first opening builds their catalogue, portrait included,
        // and nothing posts a change for that: the rows are asked again when
        // the reader comes back, so the portrait replaces the initials.
        .onChange(of: openAuthor) { closed, opened in
            guard closed != nil, opened == nil else { return }
            Task { await viewModel.load(keepingDepth: true) }
        }
    }
}

/// The author a row opens: the key the page is asked by, and the name its
/// title shows while it loads.
struct AuthorDestination: Hashable, Identifiable {
    let key: String
    let name: String
    /// An author a friend loves, offered by Découvrir: the reader may hold
    /// nothing of theirs.
    var isOffered = false
    var id: String { key }

    init(_ author: FollowedAuthor) {
        key = author.key
        name = author.name
    }

    init(key: String, name: String, isOffered: Bool = false) {
        self.key = key
        self.name = name
        self.isOffered = isOffered
    }
}
