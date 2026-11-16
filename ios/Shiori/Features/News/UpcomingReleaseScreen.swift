import SwiftUI

/// A release opened from a list, connected: pushed in the frame of the tap on
/// `PendingReleasePage`, the cover and title the list already had, while it
/// looks the release up among the release watches; then the page it opens
/// in its place — the announced volume, the awaited edition, the author, the
/// narrator. An author's or a narrator's page needs no lookup and is drawn at
/// once.
struct UpcomingReleaseScreen: View {
    let release: UpcomingRelease
    private let client: DiscoverClient

    @State private var phase: Phase
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    private enum Phase {
        case pending(PendingReleasePage.Phase)
        case found(UpcomingReleaseDestination)
    }

    init(release: UpcomingRelease, client: DiscoverClient = .live) {
        self.release = release
        self.client = client
        _phase = State(initialValue: UpcomingReleaseDestination.immediate(release).map { .found($0) } ?? .pending(.loading))
    }

    var body: some View {
        switch phase {
        case let .found(destination):
            destinationScreen(destination)
        case let .pending(pending):
            PendingReleasePage(
                release: release,
                phase: pending,
                showsClose: closing.showsCloseButton,
                onClose: { closing.close(dismissPresentation) },
                onRetry: resolve
            )
            .task { await resolve() }
        }
    }

    @ViewBuilder
    private func destinationScreen(_ destination: UpcomingReleaseDestination) -> some View {
        switch destination {
        case let .announced(volume):
            AnnouncedVolumeScreen(saga: volume.saga, volume: volume.volume)
        case let .awaited(edition):
            AwaitedEditionScreen(edition: edition)
        case let .author(author):
            AuthorScreen(key: author.key, name: author.name, isOffered: false)
        case let .narrator(narrator):
            NarratorScreen(key: narrator.key, name: narrator.name)
        }
    }

    private func resolve() async {
        if case .pending(.failed) = phase { phase = .pending(.loading) }
        do {
            let found = try await UpcomingReleaseDestination.of(release, client: client)
            phase = found.map { .found($0) } ?? .pending(.missing)
        } catch {
            if isCancellation(error) { return }
            phase = .pending(.failed(reportError(error)))
        }
    }
}

#if DEBUG
#Preview("Announced") {
    NavigationStack {
        UpcomingReleaseScreen(release: .authorPreview, client: .preview)
    }
}
#endif
