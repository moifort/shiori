import SwiftUI

/// A book wished for, connected: opened from the pile's wishlist rail.
/// Describes it as it opens; once added or taken off the list, the page
/// closes on the list that no longer holds it.
struct WishScreen: View {
    private let coverClient: ReleaseCoverClient
    @State private var choosesCover = false
    @State private var openedFromSaga: ReleaseSagaDestination?
    @State private var viewModel: WishViewModel
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

    init(
        wish: Wish,
        client: WishlistClient = .live,
        discover: DiscoverClient = .live,
        coverClient: ReleaseCoverClient = .live
    ) {
        self.coverClient = coverClient
        _viewModel = State(initialValue: WishViewModel(wish: wish, client: client, discover: discover))
    }

    var body: some View {
        WishPage(
            wish: viewModel.wish,
            shown: viewModel.shown,
            storeURL: viewModel.storeURL,
            isDescribing: viewModel.isDescribing,
            showsClose: closing.showsCloseButton,
            onClose: dismiss,
            onAdd: { status in if await viewModel.add(status: status) { dismiss() } },
            onRemove: { if await viewModel.remove() { dismiss() } },
            onChooseCover: { choosesCover = true },
            sagaVolumes: viewModel.saga.volumes,
            sagaCurrentId: viewModel.saga.currentId,
            onOpenSaga: { openedFromSaga = viewModel.saga.destination.map { .saga($0) } },
            onOpenSagaVolume: { openedFromSaga = .volume($0) },
            onOpenSagaLacking: { openedFromSaga = .lacking($0) }
        )
        .task { await viewModel.describe() }
        .task(id: viewModel.namedSeriesId) { await viewModel.loadSaga() }
        .releaseSagaDestinations($openedFromSaga, saga: viewModel.saga)
        .releaseCoverPicker(
            isPresented: $choosesCover,
            book: viewModel.shown,
            releaseKey: viewModel.releaseKey,
            client: coverClient,
            onChosen: viewModel.drawCover
        )
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
        WishScreen(wish: Wish.previews[0], client: .preview, discover: .preview, coverClient: .preview)
    }
}
