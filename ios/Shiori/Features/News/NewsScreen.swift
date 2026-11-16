import SwiftUI

/// The Actu tab, connected: owns the ViewModel, its loads, and what a
/// tap opens. Draws `NewsPage`.
///
/// What opens is what the app already has: a friend's book on its read-only
/// page, an author's page, a narrator's page.
struct NewsScreen: View {
    @State private var viewModel: NewsViewModel
    @State private var detail: NewsDetail?
    @State private var showsAlerts = false

    init(client: NewsClient = .live) {
        _viewModel = State(initialValue: NewsViewModel(client: client))
    }

    var body: some View {
        DetailSplit(item: $detail) {
            NewsPage(
                agenda: viewModel.agenda(),
                wished: viewModel.wished,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                alertsSilenced: viewModel.alertsSilenced,
                onAction: handle
            )
            .sheet(isPresented: $showsAlerts, onDismiss: { Task { await viewModel.loadAlerts() } }) {
                NavigationStack {
                    NotificationSettingsScreen(onDone: { showsAlerts = false })
                }
                .presentationDetents([.medium, .large])
            }
            // Shared the moment it comes back, as the Partagé tab does.
            .sheet(item: $viewModel.invitation) { invitation in
                InvitationSheet(invitation: invitation, myShelf: nil)
            }
        } detail: { detail in
            detailContent(detail)
        }
        .task { await viewModel.loadOnAppear() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: NewsDetail) -> some View {
        switch detail {
        case let .friendBook(event):
            FriendBookScreen(friendId: event.friendId, bookId: event.bookId, friendName: event.friendName)
        case let .author(author):
            AuthorScreen(key: author.key, name: author.name, isOffered: false)
        case let .narrator(narrator):
            NarratorScreen(key: narrator.key, name: narrator.name)
        case .upcoming:
            UpcomingReleasesScreen(releases: viewModel.calendar().releases)
        case let .release(release):
            UpcomingReleaseScreen(release: release)
        case let .suggestion(suggestion):
            SuggestionScreen(suggestion: suggestion)
        case let .award(winner):
            AwardWinnerScreen(winner: winner)
        }
    }

    private func handle(_ action: NewsAction) async {
        switch action {
        case let .open(card): openCard(card)
        case let .wish(card): await viewModel.wish(card)
        case let .dismiss(card): await viewModel.dismiss(card)
        case .openUpcoming: open(.upcoming)
        case .invite: await viewModel.invite()
        case .openAlerts: showsAlerts = true
        case .refresh: await viewModel.load()
        }
    }

    /// A card's book on the page the rest of the app opens it on: a friend's
    /// on its read-only page, a release on the volume, edition, author or
    /// narrator it came from, a discovery or a prize on its own. Pushed in
    /// the frame of the tap: a release looks itself up behind its loader.
    private func openCard(_ card: NewsCard) {
        switch card {
        case let .friend(move): open(.friendBook(move.lead))
        case let .released(.release(release, _)), let .upcoming(release):
            open(.release(release))
        case let .released(.narrator(news, _)): open(.narrator(.init(key: news.narratorKey, name: news.narrator)))
        case let .suggestion(suggestion): open(.suggestion(suggestion))
        case let .award(winner): open(.award(winner))
        }
    }

    private func open(_ target: NewsDetail) {
        detail = target
    }
}

private enum NewsDetail: Identifiable {
    case friendBook(FeedEvent)
    case author(AuthorDestination)
    case narrator(NarratorDestination)
    case upcoming
    case release(UpcomingRelease)
    case suggestion(Suggestion)
    case award(AwardWinner)

    var id: String {
        switch self {
        case .upcoming: "upcoming"
        case let .release(release): "release-\(release.id)"
        case let .friendBook(event): "friend-book-\(event.id)"
        case let .author(author): "author-\(author.id)"
        case let .narrator(narrator): "narrator-\(narrator.id)"
        case let .suggestion(suggestion): "suggestion-\(suggestion.id)"
        case let .award(winner): "award-\(winner.id)"
        }
    }
}

/// The full list of what is announced, opened from the head of Actualités'
/// "À venir" title alone: a row pushes on the list's own stack the page its
/// card opens, in the frame of the tap.
private struct UpcomingReleasesScreen: View {
    let releases: [UpcomingRelease]
    @State private var opened: UpcomingRelease?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    var body: some View {
        UpcomingReleasesPage(releases: releases) { opened = $0 }
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        closing.close(dismissPresentation)
                    }
                }
            }
        }
        .pushesDetail(item: $opened) { UpcomingReleaseScreen(release: $0) }
    }
}

#Preview("Smoke") {
    NewsScreen(client: .preview)
}
