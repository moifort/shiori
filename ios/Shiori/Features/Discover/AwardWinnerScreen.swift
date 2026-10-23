import SwiftUI

/// An award winner opened from Découvrir, connected: describes it as it
/// opens, and closes at once on the "+" while the server is told behind it.
struct AwardWinnerScreen: View {
    @State private var viewModel: AwardWinnerViewModel
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

    init(winner: AwardWinner, client: DiscoverClient = .live) {
        _viewModel = State(initialValue: AwardWinnerViewModel(winner: winner, client: client))
    }

    var body: some View {
        AwardWinnerPage(
            winner: viewModel.winner,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton
        ) { action in
            // Read before the page closes: the server is told behind it.
            let model = viewModel
            dismiss()
            switch action {
            case .close: break
            case .add: await model.add()
            case let .awaitEdition(format): await model.awaitEdition(format)
            }
        }
        .task { await viewModel.describe() }
    }
}

#Preview("Smoke") {
    NavigationStack {
        AwardWinnerScreen(winner: .preview, client: .preview)
    }
}
