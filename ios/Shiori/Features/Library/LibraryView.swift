import SwiftUI

/// The Library tab's coordinator: owns the view model, the navigation stack and
/// the sheets, and maps between the domain and the pure page below it. A book
/// opens as a sheet over the list, as a wine does in Vinarium.
struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var selectedBook: Book?
    @State private var showManualAdd = false

    var body: some View {
        NavigationStack {
            LibraryPage(
                sections: viewModel.sections,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                filter: $viewModel.filter,
                onRetry: { Task { await viewModel.load() } },
                onAddManually: { showManualAdd = true },
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
        .task { await viewModel.load() }
    }
}
