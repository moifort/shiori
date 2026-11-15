import SwiftUI

/// An awaited edition, connected: opened from the home page, "Actualités",
/// the pile, the wishlist, an author's page or a book's. Describes it as it
/// opens. Giving it up is the opener's when it holds the list the edition
/// leaves and passes `onStop`; otherwise the screen gives it up itself, and
/// the lists read it again on the notice the call posts.
struct AwaitedEditionScreen: View {
    private let onStop: (() -> Void)?

    @State private var viewModel: AwaitedEditionViewModel
    @State private var openedVolume: Book?
    @State private var openedSaga: SeriesDestination?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(edition: AwaitedEdition, client: DiscoverClient = .live, onStop: (() -> Void)? = nil) {
        self.onStop = onStop
        _viewModel = State(initialValue: AwaitedEditionViewModel(edition: edition, client: client))
    }

    var body: some View {
        AwaitedEditionPage(
            edition: viewModel.edition,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            added: viewModel.added,
            sagaVolumes: viewModel.sagaVolumes,
            showsClose: closing.showsCloseButton
        ) { action in
            switch action {
            case .close:
                dismiss()
            case .add:
                await viewModel.add()
            case .stopAwaiting:
                if let onStop {
                    onStop()
                    dismiss()
                } else if await viewModel.stopAwaiting() {
                    dismiss()
                }
            case let .openVolume(book):
                openedVolume = book
            case let .openSaga(seriesId):
                openedSaga = SeriesDestination(seriesId: seriesId)
            }
        }
        .task { await viewModel.describe() }
        .task { await viewModel.loadSaga() }
        .reloadsOnWideChange { await viewModel.loadSaga() }
        .navigationDestination(item: $openedVolume) { book in
            BookScreen(bookId: book.id)
                .closesAsPushed()
        }
        .navigationDestination(item: $openedSaga) { destination in
            SeriesScreen(seriesId: destination.seriesId)
                .closesAsPushed()
        }
        .alert(
            "Action impossible",
            isPresented: .init(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }
}

#Preview("Smoke") {
    NavigationStack {
        AwaitedEditionScreen(edition: .preview, client: .preview)
    }
}
