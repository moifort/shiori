import SwiftUI

/// An awaited edition, connected: opened from Découvrir, the home page, an
/// author's page or a book's. Describes it as it opens; giving it up is the
/// opener's, which holds the list it leaves.
struct AwaitedEditionScreen: View {
    private let onStop: () -> Void

    @State private var viewModel: AwaitedEditionViewModel
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(edition: AwaitedEdition, client: DiscoverClient = .live, onStop: @escaping () -> Void) {
        self.onStop = onStop
        _viewModel = State(initialValue: AwaitedEditionViewModel(edition: edition, client: client))
    }

    var body: some View {
        AwaitedEditionPage(
            edition: viewModel.edition,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton
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
