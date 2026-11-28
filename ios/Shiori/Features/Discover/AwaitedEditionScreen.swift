import SwiftUI

/// An awaited edition, connected: opened from the home page, "Actualités",
/// the pile, the wishlist, an author's page or a book's. Describes it as it
/// opens. Giving it up is the opener's when it holds the list the edition
/// leaves and passes `onStop`; otherwise the screen gives it up itself, and
/// the lists read it again on the notice the call posts.
struct AwaitedEditionScreen: View {
    private let onStop: (() -> Void)?

    private let coverClient: ReleaseCoverClient
    @State private var choosesCover = false
    @State private var viewModel: AwaitedEditionViewModel
    @State private var openedFromSaga: ReleaseSagaDestination?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(
        edition: AwaitedEdition,
        client: DiscoverClient = .live,
        coverClient: ReleaseCoverClient = .live,
        onStop: (() -> Void)? = nil
    ) {
        self.onStop = onStop
        self.coverClient = coverClient
        _viewModel = State(initialValue: AwaitedEditionViewModel(edition: edition, client: client))
    }

    var body: some View {
        AwaitedEditionPage(
            edition: viewModel.edition,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            added: viewModel.added,
            taken: viewModel.taken,
            refusals: viewModel.refusals,
            sagaVolumes: viewModel.saga.volumes,
            sagaCurrentId: viewModel.saga.currentId,
            showsClose: closing.showsCloseButton
        ) { action in
            switch action {
            case .close:
                dismiss()
            case let .add(addition):
                await viewModel.add(addition)
            case .undoAdd:
                await viewModel.undoAdd()
            case .stopAwaiting:
                if let onStop {
                    onStop()
                    dismiss()
                } else if await viewModel.stopAwaiting() {
                    dismiss()
                }
            case let .openVolume(book):
                openedFromSaga = .volume(book)
            case let .openLacking(volume):
                openedFromSaga = .lacking(volume)
            case .openSaga:
                openedFromSaga = viewModel.saga.destination.map { .saga($0) }
            case .chooseCover:
                choosesCover = true
            }
        }
        .task { await viewModel.describe() }
        .releaseCoverPicker(
            isPresented: $choosesCover,
            book: viewModel.shown,
            releaseKey: viewModel.releaseKey,
            client: coverClient,
            onChosen: viewModel.drawCover
        )
        .task(id: viewModel.namedSeriesId) { await viewModel.loadSaga() }
        .reloadsOnWideChange { await viewModel.loadSaga() }
        .releaseSagaDestinations($openedFromSaga, saga: viewModel.saga)
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
        AwaitedEditionScreen(edition: .preview, client: .preview, coverClient: .preview)
    }
}
