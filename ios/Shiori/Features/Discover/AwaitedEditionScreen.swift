import SwiftUI

/// An awaited edition, connected: opened from Découvrir, the home page, an
/// author's page or a book's. Describes it as it opens; giving it up is the
/// opener's, which holds the list it leaves.
struct AwaitedEditionScreen: View {
    private let onStop: () -> Void

    @State private var viewModel: AwaitedEditionViewModel
    @State private var openedVolume: Book?
    @State private var openedSaga: SeriesDestination?
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
                onStop()
                dismiss()
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
            "Ajout impossible",
            isPresented: .init(get: { viewModel.addFailed != nil }, set: { if !$0 { viewModel.addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { viewModel.addFailed = nil }
        } message: {
            Text(viewModel.addFailed ?? "")
        }
    }
}

#Preview("Smoke") {
    NavigationStack {
        AwaitedEditionScreen(edition: .preview, client: .preview) {}
    }
}
