import SwiftUI

/// The Library tab's coordinator: owns the view model, the navigation stack and
/// the sheets, and maps between the domain and the pure page below it.
struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var path: [Book] = []
    @State private var showManualAdd = false

    var body: some View {
        NavigationStack(path: $path) {
            LibraryPage(
                sections: viewModel.sections,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                filter: $viewModel.filter,
                onRetry: { Task { await viewModel.load() } },
                onAddManually: { showManualAdd = true }
            )
            .navigationDestination(for: Book.self) { book in
                BookView(
                    bookId: book.id,
                    onChanged: { updated in Task { await viewModel.apply(updated) } },
                    onDeleted: { id in
                        viewModel.remove(id: id)
                        path.removeAll()
                    }
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
