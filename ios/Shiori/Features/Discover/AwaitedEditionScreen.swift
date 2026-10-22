import SwiftUI

/// An awaited edition, connected: opened from Découvrir, the home page, an
/// author's page or a book's. Describes it as it opens; giving it up is the
/// opener's, which holds the list it leaves.
struct AwaitedEditionScreen: View {
    private let onStop: () -> Void

    @State private var viewModel: AwaitedEditionViewModel
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.closeDetailPane) private var closeDetailPane
    @Environment(\.isPresented) private var isPresented

    /// Closes the sheet, or the detail beside the page on an unfolded iPhone
    /// Duo. A screen pushed or presented from inside the detail is not its
    /// root, and closes as it would anywhere else.
    private func dismiss() {
        if !isPresented, let closeDetailPane { closeDetailPane() } else { dismissSheet() }
    }


    init(edition: AwaitedEdition, client: DiscoverClient = .live, onStop: @escaping () -> Void) {
        self.onStop = onStop
        _viewModel = State(initialValue: AwaitedEditionViewModel(edition: edition, client: client))
    }

    var body: some View {
        AwaitedEditionPage(
            edition: viewModel.edition,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing
        ) { action in
            switch action {
            case .close:
                dismiss()
            case .stopAwaiting:
                onStop()
                dismiss()
            }
        }
        .task { await viewModel.describe() }
    }
}

#Preview("Smoke") {
    NavigationStack {
        AwaitedEditionScreen(edition: .preview, client: .preview) {}
    }
}
