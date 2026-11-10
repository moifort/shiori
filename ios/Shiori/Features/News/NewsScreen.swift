import SwiftUI

/// The Découvrir tab (ex-Actualités), connected: owns the ViewModel, its loads, and what a
/// tap opens. Draws `NewsPage`.
///
/// What opens is what the app already has: a friend's book on its read-only
/// page, an author's page, a narrator's page. A release alert or a book awaited
/// opens Découvrir, whole, over the tab.
struct NewsScreen: View {
    /// Held by `ContentView`, which brings it back to the books on each visit.
    @Binding var discoverShelf: LibraryShelf
    /// A book a scan's review asked to await, handed on to Découvrir.
    @Binding var awaitRequest: AwaitRequest?
    /// Set by a release alert or a book awaited: Découvrir opens at once.
    @Binding var opensDiscover: Bool

    @State private var viewModel: NewsViewModel
    @State private var detail: NewsDetail?
    @State private var showsAlerts = false

    init(
        discoverShelf: Binding<LibraryShelf>,
        awaitRequest: Binding<AwaitRequest?>,
        opensDiscover: Binding<Bool>,
        client: NewsClient = .live
    ) {
        _discoverShelf = discoverShelf
        _awaitRequest = awaitRequest
        _opensDiscover = opensDiscover
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
        .fullScreenCover(isPresented: $opensDiscover) {
            DiscoverScreen(shelf: $discoverShelf, awaitRequest: $awaitRequest)
                .overlay(alignment: .topTrailing) {
                    Button { opensDiscover = false } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 6)
                    .accessibilityLabel("Fermer")
                }
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
        case let .announced(volume):
            AnnouncedVolumeScreen(saga: volume.saga, volume: volume.volume)
        case let .awaited(edition):
            AwaitedEditionScreen(edition: edition) { Task { await viewModel.load() } }
        case let .suggestion(suggestion):
            SuggestionScreen(suggestion: suggestion)
        case let .award(winner):
            AwardWinnerScreen(winner: winner)
        }
    }

    private func handle(_ action: NewsAction) async {
        switch action {
        case let .open(card): await openCard(card)
        case let .wish(card): await viewModel.wish(card)
        case let .dismiss(card): await viewModel.dismiss(card)
        case .openUpcoming: open(.upcoming)
        case .openDiscover: opensDiscover = true
        case .invite: await viewModel.invite()
        case .openAlerts: showsAlerts = true
        case .refresh: await viewModel.load()
        }
    }

    /// A card's book on the page the rest of the app opens it on: a friend's
    /// on its read-only page, a release on the volume, edition, author or
    /// narrator it came from, a discovery or a prize on its own.
    private func openCard(_ card: NewsCard) async {
        switch card {
        case let .friend(move): open(.friendBook(move.lead))
        case let .released(.release(release, _)), let .upcoming(release):
            if let destination = await UpcomingReleaseDestination.of(release) { open(NewsDetail(destination)) }
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
    case announced(DiscoveryVolume)
    case awaited(AwaitedEdition)
    case suggestion(Suggestion)
    case award(AwardWinner)

    init(_ destination: UpcomingReleaseDestination) {
        switch destination {
        case let .announced(volume): self = .announced(volume)
        case let .awaited(edition): self = .awaited(edition)
        case let .author(author): self = .author(author)
        case let .narrator(narrator): self = .narrator(narrator)
        }
    }

    var id: String {
        switch self {
        case .upcoming: "upcoming"
        case let .announced(volume): "announced-\(volume.id)"
        case let .awaited(edition): "awaited-\(edition.id)"
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
/// card opens.
private struct UpcomingReleasesScreen: View {
    let releases: [UpcomingRelease]
    @State private var announced: DiscoveryVolume?
    @State private var awaited: AwaitedEdition?
    @State private var author: AuthorDestination?
    @State private var narrator: NarratorDestination?
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    var body: some View {
        UpcomingReleasesPage(releases: releases) { release in
            Task {
                switch await UpcomingReleaseDestination.of(release) {
                case let .announced(volume): announced = volume
                case let .awaited(edition): awaited = edition
                case let .author(destination): author = destination
                case let .narrator(destination): narrator = destination
                case nil: break
                }
            }
        }
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        closing.close(dismissPresentation)
                    }
                }
            }
        }
        .pushesDetail(item: $author) { author in
            AuthorScreen(key: author.key, name: author.name, isOffered: false)
        }
        .pushesDetail(item: $announced) { volume in
            AnnouncedVolumeScreen(saga: volume.saga, volume: volume.volume)
        }
        .pushesDetail(item: $awaited) { edition in
            AwaitedEditionScreen(edition: edition) {}
        }
        .pushesDetail(item: $narrator) { narrator in
            NarratorScreen(key: narrator.key, name: narrator.name)
        }
    }
}

#Preview("Smoke") {
    NewsScreen(
        discoverShelf: .constant(.books),
        awaitRequest: .constant(nil),
        opensDiscover: .constant(false),
        client: .preview
    )
}
