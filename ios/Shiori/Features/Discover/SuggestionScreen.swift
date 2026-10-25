import SwiftUI

/// What took a suggestion off the line.
enum SuggestionOutcome {
    case added
    case awaited
    /// "Pas intéressé" or "Je n'aime pas".
    case dismissed(DismissalReason)
}

/// A suggestion, connected: opened from Découvrir's discoveries line or the
/// home page. Describes it as it opens; an addition or a wait closes the page
/// at once and is sent behind it, a dismissal is the opener's, which holds the
/// line.
struct SuggestionScreen: View {
    /// The suggestion left the line: added, awaited or dismissed.
    private let onDone: (SuggestionOutcome) -> Void

    @State private var viewModel: SuggestionViewModel
    @State private var openReference: SuggestionReference?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(suggestion: Suggestion, client: DiscoverClient = .live, onDone: @escaping (SuggestionOutcome) -> Void = { _ in }) {
        self.onDone = onDone
        _viewModel = State(initialValue: SuggestionViewModel(suggestion: suggestion, client: client))
    }

    var body: some View {
        SuggestionPage(
            suggestion: viewModel.suggestion,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton
        ) { action in
            // Held apart: the page is gone by the time the call returns.
            let model = viewModel
            switch action {
            case .close:
                dismiss()
            case let .add(status):
                close(.added)
                await model.add(status: status)
            case let .awaitEdition(format):
                close(.awaited)
                await model.awaitEdition(format)
            case let .dismiss(reason):
                close(.dismissed(reason))
            case let .openReference(reference):
                openReference = reference
            }
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

    private func close(_ outcome: SuggestionOutcome) {
        onDone(outcome)
        dismiss()
    }
}

#Preview("Smoke") {
    NavigationStack {
        SuggestionScreen(suggestion: .preview, client: .preview)
    }
}
