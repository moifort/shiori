import SwiftUI

/// The release notes, connected.
struct ChangelogScreen: View {
    @State private var viewModel: ChangelogViewModel

    init(client: SettingsClient = .live) {
        _viewModel = State(initialValue: ChangelogViewModel(client: client))
    }

    var body: some View {
        ChangelogPage(
            entries: viewModel.entries,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) {
            await viewModel.load()
        }
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack { ChangelogScreen(client: .preview) }
}
