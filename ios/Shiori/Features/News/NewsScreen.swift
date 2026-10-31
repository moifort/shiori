import SwiftUI

/// The Actualités tab, connected: owns the ViewModel, its loads, and what a
/// tap opens. Draws `NewsPage`.
///
/// What opens is what the app already has: a friend's book on its read-only
/// page, an author's page, an award winner's page. The "Prochainement" header
/// opens Découvrir, whole, over the tab — its series, authors, awards and
/// awaited editions stay where they were.
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
                sections: NewsFeedLayout.sections(
                    events: viewModel.shownEvents,
                    spotlight: viewModel.spotlight,
                    award: viewModel.shownWinner
                ),
                calendar: viewModel.calendar(),
                format: viewModel.format,
                horizon: $viewModel.horizon,
                selectedDay: $viewModel.selectedDay,
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
        case let .winner(winner):
            AwardWinnerScreen(winner: winner)
        }
    }

    private func handle(_ action: NewsAction) async {
        switch action {
        case let .selectFormat(format): viewModel.format = format
        case let .openFriendBook(event): detail = .friendBook(event)
        case let .take(event, format): await viewModel.take(event, as: format)
        case let .openAuthor(release):
            if let author = release.author { detail = .author(.init(key: author.key, name: author.name)) }
        case let .openWinner(winner): detail = .winner(winner)
        case let .addWinner(winner): await viewModel.add(winner)
        case .dismissWinner: viewModel.dismissWinner()
        // Narrators' news has no source yet: the row is never drawn.
        case .openNarrator, .addNarrator: break
        case .openUpcoming: opensDiscover = true
        case .openAlerts: showsAlerts = true
        case let .prefetch(id): await viewModel.prefetchIfNeeded(for: id)
        case .loadMore: await viewModel.loadMore()
        case .refresh: await viewModel.load()
        }
    }
}

private enum NewsDetail: Identifiable {
    case friendBook(FeedEvent)
    case author(AuthorDestination)
    case winner(AwardWinner)

    var id: String {
        switch self {
        case let .friendBook(event): "friend-book-\(event.id)"
        case let .author(author): "author-\(author.id)"
        case let .winner(winner): "winner-\(winner.id)"
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
