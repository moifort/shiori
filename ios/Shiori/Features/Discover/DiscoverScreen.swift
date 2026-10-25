import SwiftUI

/// The Découvrir tab, connected: owns the ViewModel, its loads and the change
/// notices, and every page the tab opens, pushed or beside it. Draws
/// `DiscoverPage`.
///
/// The server looks the sagas up on the web once a week. The tab opens on
/// everything it last showed — the rows, the friends' picks, the books awaited
/// — brought up to date silently underneath, as the Series tab is. On the very
/// first look at a format, when nothing followed in it was ever looked up, it
/// is all looked up at once; a saga or an author followed since waits for the
/// hourly pass.
struct DiscoverScreen: View {
    /// Held by `ContentView`, which brings it back to the books on each visit.
    @Binding var shelf: LibraryShelf
    /// A book a scan's review asked to await, handed over by `ContentView`:
    /// taken at once, its tile shown and scrolled to.
    @Binding var awaitRequest: AwaitRequest?
    private let client: DiscoverClient

    @State private var viewModel: DiscoverViewModel
    /// What the page opened: pushed over it on a phone, beside it on an
    /// unfolded iPhone Duo.
    @State private var detail: DiscoverDetail?
    @State private var showsAlerts = false

    init(
        shelf: Binding<LibraryShelf>,
        awaitRequest: Binding<AwaitRequest?> = .constant(nil),
        client: DiscoverClient = .live,
        snapshots: DiscoverSnapshots = .disk
    ) {
        _shelf = shelf
        _awaitRequest = awaitRequest
        self.client = client
        _viewModel = State(initialValue: DiscoverViewModel(client: client, snapshots: snapshots))
    }

    var body: some View {
        DetailSplit(item: $detail, onClose: afterClosing) {
            DiscoverPage(
                shelf: $shelf,
                feed: viewModel.feed,
                awaited: viewModel.awaitedSoon,
                focusedAwaited: viewModel.focusedAwaited,
                awards: viewModel.shownAwards,
                discoveries: viewModel.discoveriesLine,
                isLookingUp: viewModel.isLookingUp,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                alertsSilenced: viewModel.alertsSilenced,
                onAction: handle
            )
            // The release alerts, where the releases are; the bell is read
            // again when they close.
            .sheet(isPresented: $showsAlerts, onDismiss: { Task { await viewModel.loadAlerts() } }) {
                NavigationStack {
                    NotificationSettingsScreen(onDone: { showsAlerts = false })
                }
                .presentationDetents([.medium, .large])
            }
        } detail: { detail in
            detailContent(detail)
        }
        // One task for every section: six side by side asked the same
        // sections again on each visit, and twice when the format moved.
        .task { await viewModel.loadOnAppear() }
        .onDisappear { viewModel.dropFocus() }
        // Apart from the view's task: the server looks the edition up on the
        // web before it answers, and leaving the tab must not call that off.
        .onChange(of: awaitRequest, initial: true) { _, request in
            guard let request else { return }
            awaitRequest = nil
            Task { await viewModel.awaitScanned(request) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task { await viewModel.awaitedChanged() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.libraryChanged() }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: DiscoverDetail) -> some View {
        switch detail {
        case let .series(row):
            SeriesScreen(seriesId: row.series.seriesId)
        case let .volume(opened):
            AnnouncedVolumeScreen(saga: opened.saga, volume: opened.volume, client: client)
        case let .friendBook(loved):
            FriendBookScreen(
                friendId: loved.lovers.first?.userId ?? "",
                bookId: loved.book.id,
                friendName: loved.lovers.first?.displayName ?? ""
            )
        case let .friendSaga(loved):
            // The reader holds no volume of it: the saga is named to the
            // server, which catalogues it if nobody has yet.
            SeriesScreen(
                seriesId: loved.saga.seriesId,
                proposal: loved.saga.author.map { SeriesProposal(name: loved.saga.name, author: $0) }
            )
        case let .awaited(edition):
            AwaitedEditionScreen(edition: edition, client: client) {
                Task { await viewModel.stopAwaiting(edition) }
            }
        case let .suggestion(suggestion):
            SuggestionScreen(suggestion: suggestion, client: client) { outcome in
                guard case let .dismissed(reason) = outcome else { return }
                Task {
                    await viewModel.dismiss(suggestion, reason: reason, format: viewModel.awardsFormat)
                }
            }
        case let .winner(winner):
            AwardWinnerScreen(winner: winner, client: client)
        case let .author(opened):
            // The Library's own author page; a saga pushes after it.
            AuthorScreen(key: opened.key, name: opened.name, isOffered: opened.isOffered)
        }
    }

    /// What a closed page leaves to ask again. A suggestion closed: an
    /// addition or a wait takes it off, and the next one comes in. A winner
    /// closed: the cover its page found is drawn on the tile.
    private func afterClosing(_ detail: DiscoverDetail) {
        switch detail {
        case .suggestion: Task { await viewModel.loadDiscoveries(viewModel.awardsFormat) }
        case .winner: Task { await viewModel.loadAwards(viewModel.awardsFormat) }
        case .series, .volume, .friendBook, .friendSaga, .awaited, .author: break
        }
    }

    private func handle(_ action: DiscoverAction) async {
        switch action {
        case let .openSeries(row): detail = .series(row)
        case let .openVolume(volume): detail = .volume(volume)
        case let .openAuthor(author): detail = .author(author)
        case let .openFriendBook(loved): detail = .friendBook(loved)
        case let .openFriendSaga(loved): detail = .friendSaga(loved)
        case let .openAwaited(edition): detail = .awaited(edition)
        case let .openWinner(winner): detail = .winner(winner)
        case let .openSuggestion(suggestion): detail = .suggestion(suggestion)
        case .openAlerts: showsAlerts = true
        case .refresh: await viewModel.refresh()
        case .retry: await viewModel.loadAll()
        }
    }
}

/// What Découvrir opens, pushed over it or beside it.
private enum DiscoverDetail: Identifiable {
    case series(SagaDiscovery)
    case volume(DiscoveryVolume)
    case friendBook(LovedBook)
    case friendSaga(LovedSaga)
    case awaited(AwaitedEdition)
    case suggestion(Suggestion)
    case winner(AwardWinner)
    case author(AuthorDestination)

    var id: String {
        switch self {
        case let .series(row): "series-\(row.id)"
        case let .volume(volume): "volume-\(volume.id)"
        case let .friendBook(loved): "friend-book-\(loved.id)"
        case let .friendSaga(loved): "friend-saga-\(loved.id)"
        case let .awaited(edition): "awaited-\(edition.id)"
        case let .suggestion(suggestion): "suggestion-\(suggestion.id)"
        case let .winner(winner): "winner-\(winner.id)"
        case let .author(author): "author-\(author.id)"
        }
    }
}

#Preview("Smoke") {
    DiscoverScreen(shelf: .constant(.books), client: .preview, snapshots: .none)
}
