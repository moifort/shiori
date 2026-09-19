import SwiftUI

/// The Library tab's coordinator: owns the view model, the navigation stack and
/// the sheets, and maps between the domain and the pure page below it. A book
/// opens as a sheet over the list, as a wine does in Vinarium.
struct LibraryView: View {
    /// A shelf another tab wants shown. Applied as the filter, then cleared so the
    /// reader's own filter changes are not overridden later.
    @Binding var filterRequest: ReadingStatus?

    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: Book?
    @State private var showManualAdd = false
    @State private var showAudibleImport = false

    var body: some View {
        NavigationStack {
            LibraryPage(
                sections: viewModel.sections,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                filter: $viewModel.filter,
                onRetry: { Task { await viewModel.load() } },
                onAddManually: { showManualAdd = true },
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
        .sheet(isPresented: $showManualAdd) {
            ManualAddView(onAdded: { _ in
                showManualAdd = false
                Task { await viewModel.load() }
            })
        }
        .sheet(isPresented: $showAudibleImport) {
            // An import can add a hundred books across a dozen sagas, so the
            // list is refetched rather than patched row by row as a single
            // edit is.
            AudibleImportView(onImported: { _ in
                showAudibleImport = false
                Task { await viewModel.load() }
            })
        }
        .task { await viewModel.load() }
        .onChange(of: filterRequest, initial: true) { _, request in
            guard let request else { return }
            viewModel.filter = request
            filterRequest = nil
        }
    }
}
