import SwiftUI

/// The Library tab's books, connected: owns the view model, the navigation and
/// the sheets, and maps between the domain and the pure page below it. A book
/// is pushed over the list, or set beside it on an unfolded iPhone Duo.
struct LibraryScreen: View {
    /// Opens the add sheet, which the tab bar's scan button owns: every way a
    /// book gets in sits behind that one entry, on every tab.
    let onAdd: () -> Void
    /// A view another tab asked this one to open on, taken and cleared as
    /// soon as the tab shows it.
    @Binding var requestedMode: LibraryRequest?
    /// The shelf capsule of the Library tab, drawn under the list. Nil where
    /// the list stands alone.
    var shelf: Binding<LibraryShelf>? = nil

    @State private var viewModel: LibraryViewModel
    @State private var selectedBook: Book?
    @State private var showSearch = false

    init(
        onAdd: @escaping () -> Void,
        requestedMode: Binding<LibraryRequest?>,
        shelf: Binding<LibraryShelf>? = nil,
        client: LibraryClient = .live
    ) {
        self.onAdd = onAdd
        _requestedMode = requestedMode
        self.shelf = shelf
        // A request the tab is created with is shown from the first frame:
        // taken in the task, the default mosaic would flash before it.
        let viewModel = LibraryViewModel(client: client)
        if let request = requestedMode.wrappedValue { viewModel.show(request) }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // A book is pushed over the list on a phone, and set beside it on an
        // unfolded iPhone Duo, as Mail sets a message beside its inbox.
        DetailSplit(item: $selectedBook) {
            LibraryPage(
                mode: $viewModel.mode,
                filter: $viewModel.filter,
                // A shelf opens on its mosaic, every time its pill is tapped.
                layout: $viewModel.layout,
                sections: viewModel.sections,
                awaitedBookIds: viewModel.awaitedBookIds,
                focusedBookId: viewModel.focusedBookId,
                // The favourites mix every status: their rows still say which.
                showsStatus: viewModel.filter?.status == nil,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                hasMore: viewModel.hasMore,
                loadMoreFailed: viewModel.loadMoreFailed
            ) { action in
                switch action {
                case let .openBook(book): selectedBook = book
                case let .reached(id): viewModel.prefetchIfNeeded(for: id)
                case .loadMore: await viewModel.loadMore()
                case .refresh: await viewModel.load()
                case .add: onAdd()
                case .search: showSearch = true
                }
            }
            .libraryShelfPicker(shelf)
            .sheet(isPresented: $showSearch) {
                LibrarySearchScreen()
            }
        } detail: { book in
            // An edit to this book patches its own row from what the page
            // already holds, and the list lets the change notice it posts
            // pass: reloading would cost a request per edit.
            BookScreen(
                bookId: book.id,
                onChanged: { viewModel.apply($0) },
                onDeleted: { viewModel.remove(id: $0) }
            )
        }
        // Over last session's snapshot when the disk had one: the list shows at
        // once and the spinner at its top says it is being brought up to date.
        .task {
            takeRequestedMode()
            await viewModel.loadOnAppear()
        }
        .task { await viewModel.loadAwaited() }
        .onChange(of: requestedMode) { takeRequestedMode() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.loadAwaited() }
        }
        // A book added from the scanner lands in a section this list has not
        // drawn yet; a saga rated from a book's sheet lends its stars to every
        // volume. Either way the rows on screen are the old ones until the
        // server is asked again — all of them, so the reader stays where they
        // were. The book open in the sheet is the exception: its row is
        // patched from the page's own answer.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { notice in
            if let selectedBook, notice.object as? DataChange == .book(id: selectedBook.id) { return }
            Task { await viewModel.load(keepingDepth: true) }
        }
    }

    private func takeRequestedMode() {
        guard let requestedMode else { return }
        viewModel.show(requestedMode)
        self.requestedMode = nil
        if let focus = requestedMode.focus {
            Task { await viewModel.focus(on: focus) }
        }
    }
}
