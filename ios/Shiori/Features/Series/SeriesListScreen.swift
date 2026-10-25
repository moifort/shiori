import SwiftUI

/// The Series tab, connected: `SeriesListViewModel` loads the sagas page by
/// page, this screen opens one as a sheet, reloads what a change touched, and
/// hands the rest to `SeriesListPage`.
struct SeriesListScreen: View {
    /// Opens the add sheet, from the one button every empty state offers.
    var onScan: () -> Void = {}
    /// A view another tab asked this one to open on, taken and cleared as
    /// soon as the tab shows it.
    @Binding var requested: SeriesRequest?
    /// The shelf capsule of the Library tab, drawn under the list. Nil where
    /// the list stands alone.
    var shelf: Binding<LibraryShelf>? = nil

    var client: SeriesClient = .live

    @State private var viewModel: SeriesListViewModel
    /// The saga being opened. A button and a destination rather than a
    /// navigation link: the link draws a chevron on every row, and a list of
    /// sagas reads better as cards than as a menu.
    @State private var openSeries: SeriesDestination?
    /// What changed while a saga was open, kept until the reader comes back
    /// to the list: then only that saga's rows are asked again, unless
    /// something else changed too.
    @State private var openSeriesChanged = false
    @State private var changedVolumes: Set<String> = []
    @State private var changedElsewhere = false

    init(
        onScan: @escaping () -> Void = {},
        requested: Binding<SeriesRequest?>,
        shelf: Binding<LibraryShelf>? = nil,
        client: SeriesClient = .live
    ) {
        self.onScan = onScan
        _requested = requested
        self.shelf = shelf
        self.client = client
        _viewModel = State(initialValue: SeriesListViewModel(client: client))
    }

    var body: some View {
        // A saga is pushed over the list on a phone. On an unfolded iPhone
        // Duo it opens across both pages, its volumes on one and the volume
        // touched on the other, the list a tap away; partly folded, the first
        // saga of the list waits beside it before one is opened.
        DetailSplit(
            item: $openSeries,
            resting: viewModel.followed.first.map(destination(of:)),
            spreads: true
        ) {
            SeriesListPage(
                followed: viewModel.followed,
                mode: $viewModel.mode,
                stateFilter: $viewModel.stateFilter,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                hasMore: viewModel.hasMore,
                loadMoreFailed: viewModel.loadMoreFailed
            ) { action in
                switch action {
                case let .open(entry): openSeries = destination(of: entry)
                case let .reached(id): viewModel.prefetchIfNeeded(for: id)
                case .loadMore: await viewModel.loadMore()
                case .refresh: await viewModel.load()
                case .scan: onScan()
                }
            }
            .libraryShelfPicker(shelf)
            // Once, when the list first shows: a saga opens as a sheet over
            // it, and the rows it changed are asked again when the sheet
            // closes — a saga's first opening is where the server builds its
            // catalogue, which this list draws as the missing covers of the
            // strip. Over last session's snapshot when the disk had one: the rows show at once
            // and the spinner at the top says they are being brought up to date.
            .task {
                takeRequested()
                await viewModel.loadOnAppear()
            }
        } detail: { opened in
            SeriesScreen(seriesId: opened.seriesId, client: client)
        }
        .onChange(of: requested) { takeRequested() }
        // A volume finished in the library, a book scanned: the rows here say
        // so the next time the reader looks, not the next launch — all of them,
        // so the reader stays where they were. A change made from an open saga
        // waits for the reader to come back, and only that saga is asked again.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { notice in
            guard let open = openSeries else {
                Task { await viewModel.load(keepingDepth: true) }
                return
            }
            switch notice.object as? DataChange {
            case let .series(id) where id == open.seriesId:
                openSeriesChanged = true
            case let .book(id) where viewModel.holds(bookId: id, in: open):
                changedVolumes.insert(id)
            default:
                // A book scanned, a change made from another tab while this
                // saga stayed open: anything may have moved.
                changedElsewhere = true
            }
        }
        .onChange(of: openSeries) { closed, opened in
            guard let closed, opened == nil else { return }
            let reloadAll = changedElsewhere
            // A saga opened for the first time came back with the catalogue
            // its opening built: the row learns its missing volumes.
            let refreshSaga =
                openSeriesChanged || !changedVolumes.isEmpty || viewModel.lacksCatalogue(closed)
            let volumes = changedVolumes
            openSeriesChanged = false
            changedVolumes = []
            changedElsewhere = false
            if reloadAll {
                Task { await viewModel.load(keepingDepth: true) }
            } else if refreshSaga {
                Task { await viewModel.refreshRows(of: closed, changedBooks: volumes) }
            }
        }
    }

    private func takeRequested() {
        guard let requested else { return }
        viewModel.show(requested)
        self.requested = nil
    }

    /// The saga in the edition of this row: a saga held in two languages makes
    /// two rows, and each must open on its own covers.
    private func destination(of entry: FollowedSeries) -> SeriesDestination {
        SeriesDestination(seriesId: entry.seriesId)
    }
}
