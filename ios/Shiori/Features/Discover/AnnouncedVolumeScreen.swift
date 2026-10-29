import SwiftUI

/// A volume announced, connected: opened from the Books shelf of Découvrir,
/// from the home page, or from its row on the saga screen. Describes it as it
/// opens, lays out its saga's row, adds it, turns the saga's alerts on or off,
/// and pushes its saga or one of the reader's volumes.
struct AnnouncedVolumeScreen: View {
    /// Whether the page links to its saga. Not when it was opened from the saga
    /// screen, which is right under it.
    private let linksToSaga: Bool

    @State private var viewModel: AnnouncedVolumeViewModel
    @State private var showsSaga = false
    @State private var openedVolume: Book?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }


    init(saga: SagaDiscovery, volume: DiscoveredVolume, linksToSaga: Bool = true, client: DiscoverClient = .live) {
        self.linksToSaga = linksToSaga
        _viewModel = State(initialValue: AnnouncedVolumeViewModel(
            opened: DiscoveryVolume(saga: saga, volume: volume),
            client: client
        ))
    }

    var body: some View {
        AnnouncedVolumePage(
            opened: viewModel.opened,
            shown: viewModel.shown,
            isDescribing: viewModel.isDescribing,
            added: viewModel.added,
            linksToSaga: linksToSaga,
            isFollowed: viewModel.isFollowed,
            sagaVolumes: viewModel.sagaVolumes,
            showsClose: closing.showsCloseButton
        ) { action in
            switch action {
            case .close: dismiss()
            case .add: await viewModel.add()
            case .openSaga: showsSaga = true
            case .toggleFollowed: await viewModel.toggleFollowed()
            case let .openVolume(book): openedVolume = book
            }
        }
        .task { await viewModel.describe() }
        .task { await viewModel.loadSaga() }
        .reloadsOnWideChange { await viewModel.loadSaga() }
        .navigationDestination(item: $openedVolume) { book in
            BookScreen(bookId: book.id)
                .closesAsPushed()
        }
        .navigationDestination(isPresented: $showsSaga) {
            SeriesScreen(seriesId: viewModel.opened.saga.series.seriesId)
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
        AnnouncedVolumeScreen(saga: .preview, volume: SagaDiscovery.preview.releases.next!, client: .preview)
    }
}
