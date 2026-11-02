import SwiftUI

/// A suggestion, connected: opened from Découvrir's discoveries line or the
/// home page. Describes it as it opens; what the reader decides stays on the
/// page, which the opener's line catches up with once it closes.
struct SuggestionScreen: View {
    /// The opener's own way of asking the server, the home's; nil, the page's.
    private let onChoice: ((Suggestion, DiscoveryChoice) async -> Bool)?

    @State private var viewModel: SuggestionViewModel
    @State private var choices: DiscoveryChoices
    @State private var openReference: SuggestionReference?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(
        suggestion: Suggestion,
        client: DiscoverClient = .live,
        choices: DiscoveryChoices = DiscoveryChoices(),
        onChoice: ((Suggestion, DiscoveryChoice) async -> Bool)? = nil
    ) {
        self.onChoice = onChoice
        _choices = State(initialValue: choices)
        _viewModel = State(initialValue: SuggestionViewModel(suggestion: suggestion, client: client))
    }

    var body: some View {
        SuggestionPage(
            suggestion: viewModel.suggestion,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton,
            choices: choices,
            onChoice: onChoice ?? viewModel.choose
        ) { action in
            switch action {
            case .close:
                dismiss()
            case let .openReference(reference):
                openReference = reference
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
        // A saga cited by name opens the saga's page; a book, its own.
        .pushesDetail(item: $openReference) { reference in
            if reference.citesSaga, let seriesId = reference.seriesId {
                SeriesScreen(seriesId: seriesId)
            } else {
                BookScreen(bookId: reference.bookId)
            }
        }
    }
}

#Preview("Smoke") {
    NavigationStack {
        SuggestionScreen(suggestion: .preview, client: .preview)
    }
}
