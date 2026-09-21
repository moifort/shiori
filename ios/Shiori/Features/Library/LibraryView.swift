import SwiftUI

/// The Library tab's coordinator: owns the view model, the navigation stack and
/// the sheets, and maps between the domain and the pure page below it. A book
/// opens as a sheet over the list, as a wine does in Vinarium.
struct LibraryView: View {
    /// Opens the add sheet, which the tab bar's scan button owns: every way a
    /// book gets in sits behind that one entry, on every tab.
    let onAdd: () -> Void

    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: Book?
    @State private var showAudibleImport = false

    var body: some View {
        NavigationStack {
            LibraryPage(
                mode: $viewModel.mode,
                statusFilter: $viewModel.statusFilter,
                sections: viewModel.sections,
                showsStatus: !viewModel.sectionsByStatus,
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
                onImportFromAudible: { showAudibleImport = true },
                onBookTapped: { selectedBook = $0 }
            )
            .sheet(item: $selectedBook) { book in
                BookView(
                    bookId: book.id,
                    onChanged: { updated in Task { await viewModel.apply(updated) } },
                    // The sheet dismisses itself once the deletion lands.
                    onDeleted: { id in viewModel.remove(id: id) }
                )
            }
        }
        .sheet(isPresented: $showAudibleImport) {
            // An import can add a hundred books across every section, so the
            // list is refetched rather than patched row by row as a single
            // edit is.
            AudibleImportView(onImported: { _ in
                showAudibleImport = false
                Task { await viewModel.load() }
            })
        }
        // Over last session's snapshot when the disk had one: the list shows at
        // once and the spinner at its top says it is being brought up to date.
        .task { await viewModel.loadOnAppear() }
        // A book rated in a sheet moves to another tier; one added from the
        // scanner lands in a section this list has not drawn yet. Either way the
        // rows on screen are the old ones until the server is asked again.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }
}
