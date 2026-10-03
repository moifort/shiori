import SwiftUI

/// The admin screen's coordinator: loads the figures on appear and on a pull,
/// and hands them to `AdminPage`. Opened as a sheet from the home toolbar, for
/// an admin account only.
struct AdminView: View {
    @State private var viewModel = AdminViewModel()

    var body: some View {
        AdminPage(
            metrics: viewModel.metrics,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onRetry: { await viewModel.load() }
        )
        .task {
            if viewModel.metrics == nil { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
    }
}
