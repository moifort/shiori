import SwiftUI

/// A release's page while it opens: drawn in the frame of the tap with what
/// the list knew of it — cover, title, authors, date — and a loader where its
/// page will be. Pure: `UpcomingReleaseScreen` says what it is waiting for.
struct PendingReleasePage: View {
    enum Phase: Equatable {
        case loading
        /// The release watch no longer lists it.
        case missing
        /// The watch could not be read: why, and a retry.
        case failed(String)
    }

    let release: UpcomingRelease
    let phase: Phase
    var showsClose = true
    var onClose: () -> Void = {}
    var onRetry: () async -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BookHero(book: release.cover, releaseDate: release.date)
                below
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 32)
            }
        }
        .scrollEdgeEffectHidden(true, for: .top)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onClose)
                }
            }
        }
    }

    @ViewBuilder private var below: some View {
        switch phase {
        case .loading:
            ProgressView()
                .accessibilityIdentifier("pending-release-loading")
        case .missing:
            EmptyState(
                systemImage: "calendar.badge.exclamationmark",
                title: "Sortie introuvable",
                message: "Cette sortie n'est plus annoncée."
            )
        case let .failed(message):
            EmptyState.failure("Sortie indisponible", message: message, retry: onRetry)
        }
    }
}

private extension BookHero where Actions == EmptyView {
    init(book: Book, releaseDate: String?) {
        self.init(
            book: book,
            showsLength: false,
            releaseDate: releaseDate,
            countdown: releaseDate.flatMap { ReleaseDateText.countdown($0) }
        ) { EmptyView() }
    }
}

#if DEBUG
#Preview("Loading") {
    NavigationStack {
        PendingReleasePage(release: .authorPreview, phase: .loading)
    }
}

#Preview("Missing") {
    NavigationStack {
        PendingReleasePage(release: .authorPreview, phase: .missing)
    }
}

#Preview("Failed") {
    NavigationStack {
        PendingReleasePage(release: .authorPreview, phase: .failed("La connexion Internet semble interrompue."))
    }
}
#endif
