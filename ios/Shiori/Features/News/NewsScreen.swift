import SwiftUI

/// The Actualités tab, connected: owns the ViewModel, its loads, and what a
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
                tab: viewModel.tab,
                friendsHaveNews: viewModel.friendsHaveNews,
                released: viewModel.released(),
                calendar: viewModel.calendar(),
                format: viewModel.format,
                stories: viewModel.stories,
                friendSections: viewModel.friendSections(),
                friendId: viewModel.friendId,
                hasMore: viewModel.hasMore,
                pageFailed: viewModel.pageFailed,
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
        }
    }

    private func handle(_ action: NewsAction) async {
        switch action {
        case let .selectTab(tab): viewModel.tab = tab
        case let .selectFormat(format): viewModel.format = format
        case let .selectFriend(friendId): viewModel.friendId = friendId
        case let .openFriendBook(event): open(.friendBook(event))
        case let .take(event, format): await viewModel.take(event, as: format)
        case let .openAuthor(release):
            if let author = release.author { open(.author(.init(key: author.key, name: author.name))) }
        case let .openNarrator(news): open(.narrator(.init(key: news.narratorKey, name: news.narrator)))
        case let .addNarrator(news): await viewModel.add(news)
        case .invite: await viewModel.invite()
        case .openAlerts: showsAlerts = true
        case let .prefetch(id): await viewModel.prefetchIfNeeded(for: id)
        case .loadMore: await viewModel.loadMore()
        case .refresh: await viewModel.load()
        }
    }

    private func open(_ target: NewsDetail) {
        detail = target
    }
}

private enum NewsDetail: Identifiable, Hashable {
    case friendBook(FeedEvent)
    case author(AuthorDestination)
    case narrator(NarratorDestination)

    var id: String {
        switch self {
        case let .friendBook(event): "friend-book-\(event.id)"
        case let .author(author): "author-\(author.id)"
        case let .narrator(narrator): "narrator-\(narrator.id)"
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
