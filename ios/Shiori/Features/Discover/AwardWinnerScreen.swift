import SwiftUI

/// An award winner, connected: opened from Découvrir or the feed. Describes it
/// as it opens; what the reader decides stays on the page, which the opener's
/// list catches up with once it closes.
struct AwardWinnerScreen: View {
    /// The winners listed beside it, for the row at the foot of its page.
    private let others: [AwardWinner]
    private let client: DiscoverClient

    @State private var viewModel: AwardWinnerViewModel
    @State private var choices = DiscoveryChoices()
    @State private var openWinner: AwardWinner?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

    init(winner: AwardWinner, others: [AwardWinner] = [], client: DiscoverClient = .live) {
        self.others = others
        self.client = client
        _viewModel = State(initialValue: AwardWinnerViewModel(winner: winner, client: client))
    }

    var body: some View {
        AwardWinnerPage(
            winner: viewModel.winner,
            shown: viewModel.shown,
            others: others.filter { $0.id != viewModel.winner.id },
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton,
            choices: choices,
            onChoice: viewModel.choose
        ) { action in
            switch action {
            case .close: dismiss()
            case let .openWinner(winner): openWinner = winner
            }
        }
        .alert(
            "Une erreur est survenue",
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .task { await viewModel.describe() }
        .pushesDetail(item: $openWinner) { winner in
            AwardWinnerScreen(winner: winner, others: others, client: client)
        }
    }
}

#Preview("Smoke") {
    NavigationStack {
        AwardWinnerScreen(winner: .preview, others: [.goncourtPreview], client: .preview)
    }
}
