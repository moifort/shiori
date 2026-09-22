import SwiftUI

/// The Library tab's coordinator: owns the view model, the navigation stack and
/// the sheets, and maps between the domain and the pure page below it. A book
/// opens as a sheet over the list, as a wine does in Vinarium.
struct LibraryView: View {
    /// Opens the add sheet, which the tab bar's scan button owns: every way a
    /// book gets in sits behind that one entry, on every tab.
    let onAdd: () -> Void
    /// A view another tab asked this one to open on, taken and cleared as
    /// soon as the tab shows it.
    @Binding var requestedMode: LibraryRequest?

    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: Book?

    var body: some View {
        NavigationStack {
            LibraryPage(
                mode: $viewModel.mode,
                statusFilter: $viewModel.statusFilter,
                sections: viewModel.sections,
                showsStatus: viewModel.statusFilter == nil,
                isLoading: viewModel.isLoading,
                isRefreshing: viewModel.isRefreshing,
                refreshFailed: viewModel.refreshFailed,
                errorMessage: viewModel.errorMessage,
                hasMore: viewModel.hasMore,
                loadMoreFailed: viewModel.loadMoreFailed,
                onRetry: { await viewModel.load() },
                onRetryRefresh: { await viewModel.refresh() },
                onPrefetch: { viewModel.prefetchIfNeeded(for: $0) },
                onLoadMore: { await viewModel.loadMore() },
                onAdd: onAdd,
                onBookTapped: { selectedBook = $0 }
            )
            .sheet(item: $selectedBook) { book in
                // An edit reaches this list through the change notice, which
                // reloads the page once. Patching the row as well sent a second
                // request whenever the book changed section. A deletion still
                // takes the row away at once, before the reload lands.
                BookView(bookId: book.id, onDeleted: { id in viewModel.remove(id: id) })
            }
        }
        // Over last session's snapshot when the disk had one: the list shows at
        // once and the spinner at its top says it is being brought up to date.
        .task {
            takeRequestedMode()
            await viewModel.loadOnAppear()
        }
        .onChange(of: requestedMode) { takeRequestedMode() }
        // A book rated in a sheet moves to another month; one added from the
        // scanner lands in a section this list has not drawn yet. Either way the
        // rows on screen are the old ones until the server is asked again —
        // all of them, so the reader stays where they were in the list.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
    }

    private func takeRequestedMode() {
        guard let requestedMode else { return }
        viewModel.show(requestedMode)
        self.requestedMode = nil
    }
}
