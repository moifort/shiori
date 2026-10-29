import SwiftUI

/// The admin screen, connected: loads the figures on appear and on a pull,
/// and hands them to `AdminPage`. Opened as a sheet from the home toolbar, for
/// an admin account only.
struct AdminScreen: View {
    @State private var viewModel: AdminViewModel

    init(client: AdminClient = .live) {
        _viewModel = State(initialValue: AdminViewModel(client: client))
    }

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
        .reloadsOnWideChange { await viewModel.load() }
    }
}
