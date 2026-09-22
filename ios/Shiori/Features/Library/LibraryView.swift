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
    /// The shelf capsule of the Library tab, drawn under the list. Nil where
    /// the list stands alone.
    var shelf: Binding<LibraryShelf>? = nil

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
            .libraryShelfPicker(shelf)
            .sheet(item: $selectedBook) { book in
                // An edit to this book patches its own row from what the sheet
                // already holds, and the list lets the change notice it posts
                // pass: reloading would cost a request per edit.
                BookView(
                    bookId: book.id,
                    onChanged: { viewModel.apply($0) },
                    onDeleted: { viewModel.remove(id: $0) }
                )
            }
        }
        // Over last session's snapshot when the disk had one: the list shows at
        // once and the spinner at its top says it is being brought up to date.
        .task {
            takeRequestedMode()
            await viewModel.loadOnAppear()
        }
        .onChange(of: requestedMode) { takeRequestedMode() }
        // A book added from the scanner lands in a section this list has not
        // drawn yet; a saga rated from a book's sheet lends its stars to every
        // volume. Either way the rows on screen are the old ones until the
        // server is asked again — all of them, so the reader stays where they
        // were. The book open in the sheet is the exception: its row is
        // patched from the sheet's own answer.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { notice in
            if let selectedBook, notice.object as? DataChange == .book(id: selectedBook.id) { return }
            Task { await viewModel.load(keepingDepth: true) }
        }
    }

    private func takeRequestedMode() {
        guard let requestedMode else { return }
        viewModel.show(requestedMode)
        self.requestedMode = nil
    }
}
