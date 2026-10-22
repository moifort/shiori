import SwiftUI

/// A volume announced, connected: opened from the Books shelf of Découvrir,
/// from the home page, or from its row on the saga screen. Describes it as it
/// opens, adds it, and pushes its saga.
struct AnnouncedVolumeScreen: View {
    /// Whether the page links to its saga. Not when it was opened from the saga
    /// screen, which is right under it.
    private let linksToSaga: Bool

    @State private var viewModel: AnnouncedVolumeViewModel
    @State private var showsSaga = false
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.closeDetailPane) private var closeDetailPane
    @Environment(\.isPresented) private var isPresented

    /// Closes the sheet, or the detail beside the page on an unfolded iPhone
    /// Duo. A screen pushed or presented from inside the detail is not its
    /// root, and closes as it would anywhere else.
    private func dismiss() {
        if !isPresented, let closeDetailPane { closeDetailPane() } else { dismissSheet() }
    }


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
            linksToSaga: linksToSaga
        ) { action in
            switch action {
            case .close: dismiss()
            case .add: await viewModel.add()
            case .openSaga: showsSaga = true
            }
        }
        .task { await viewModel.describe() }
        .navigationDestination(isPresented: $showsSaga) {
            SeriesScreen(seriesId: viewModel.opened.saga.series.seriesId, language: viewModel.opened.saga.series.language)
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
