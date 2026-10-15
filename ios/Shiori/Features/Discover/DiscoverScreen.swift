import SwiftUI

/// The Découvrir tab, connected: owns the ViewModel, its loads and the change
/// notices, and every page the tab opens as a sheet. Draws `DiscoverPage`.
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
    private let client: DiscoverClient

    @State private var viewModel: DiscoverViewModel
    @State private var openSeries: SagaDiscovery?
    /// The volume whose page is open, announced or just out.
    @State private var openVolume: DiscoveryVolume?
    @State private var openAuthor: AuthorDestination?
    @State private var openFriendBook: LovedBook?
    @State private var openFriendSaga: LovedSaga?
    @State private var openAwaited: AwaitedEdition?
    @State private var openWinner: AwardWinner?
    @State private var openSuggestion: Suggestion?
    @State private var showsAlerts = false

    init(shelf: Binding<LibraryShelf>, client: DiscoverClient = .live, snapshots: DiscoverSnapshots = .disk) {
        _shelf = shelf
        self.client = client
        _viewModel = State(initialValue: DiscoverViewModel(client: client, snapshots: snapshots))
    }

    var body: some View {
        NavigationStack {
            DiscoverPage(
                shelf: $shelf,
                feed: viewModel.feed,
                awards: viewModel.shownAwards,
                discoveries: viewModel.discoveriesLine,
                isLookingUp: viewModel.isLookingUp,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                alertsSilenced: viewModel.alertsSilenced,
                onAction: handle
            )
            // A sheet, as a book opens from the library.
            .sheet(item: $openSeries) { row in
                NavigationStack {
                    SeriesScreen(
                        seriesId: row.series.seriesId,
                        language: row.series.language,
                        isSheet: true
                    )
                }
            }
            .sheet(item: $openVolume) { opened in
                NavigationStack {
                    AnnouncedVolumeScreen(saga: opened.saga, volume: opened.volume, client: client)
                }
            }
            .sheet(item: $openFriendBook) { loved in
                NavigationStack {
                    FriendBookScreen(
                        friendId: loved.lovers.first?.userId ?? "",
                        bookId: loved.book.id,
                        friendName: loved.lovers.first?.displayName ?? ""
                    )
                }
            }
            // The reader holds no volume of it: the saga is named to the
            // server, which catalogues it if nobody has yet.
            .sheet(item: $openFriendSaga) { loved in
                NavigationStack {
                    SeriesScreen(
                        seriesId: loved.saga.seriesId,
                        language: loved.saga.language,
                        isSheet: true,
                        proposal: loved.saga.author.map { SeriesProposal(name: loved.saga.name, author: $0) }
                    )
                }
            }
            .sheet(item: $openAwaited) { edition in
                NavigationStack {
                    AwaitedEditionView(edition: edition) {
                        Task { await viewModel.stopAwaiting(edition) }
                    }
                }
            }
            // Closed, the line is asked again: an addition or a wait takes
            // the suggestion off, and the next one comes in.
            .sheet(item: $openSuggestion, onDismiss: {
                Task { await viewModel.loadDiscoveries(viewModel.awardsFormat) }
            }) { suggestion in
                NavigationStack {
                    SuggestionView(suggestion: suggestion) { outcome in
                        guard outcome == .dismissed else { return }
                        Task { await viewModel.dismiss(suggestion, format: viewModel.awardsFormat) }
                    }
                }
            }
            // Closed, the strip is asked again: the cover the page found
            // when it was described is drawn on the tile.
            .sheet(item: $openWinner, onDismiss: {
                Task { await viewModel.loadAwards(viewModel.awardsFormat) }
            }) { winner in
                NavigationStack { AwardWinnerScreen(winner: winner, client: client) }
            }
            // The Library's own author page, in its own stack so a saga
            // pushes inside it.
            .sheet(item: $openAuthor) { opened in
                NavigationStack {
                    AuthorView(key: opened.key, name: opened.name, isSheet: true, isOffered: opened.isOffered)
                }
            }
            // The release alerts, where the releases are; the bell is read
            // again when they close.
            .sheet(isPresented: $showsAlerts, onDismiss: { Task { await viewModel.loadAlerts() } }) {
                NavigationStack {
                    NotificationSettingsScreen(onDone: { showsAlerts = false })
                }
                .presentationDetents([.medium, .large])
            }
        }
        .task { await viewModel.loadOnAppear() }
        .task { await viewModel.loadPicks() }
        .task { await viewModel.loadAlerts() }
        .task {
            for format in ReleaseFormat.allCases { await viewModel.loadAwaited(format) }
        }
        // The format follows what the reader holds, known once the rows are in.
        .task(id: viewModel.awardsFormat) { await viewModel.loadAwards(viewModel.awardsFormat) }
        .task(id: viewModel.awardsFormat) { await viewModel.loadDiscoveries(viewModel.awardsFormat) }
        // The Authors shelf carries the editions awaited too.
        .onReceive(NotificationCenter.default.publisher(for: .shioriAwaitedEditionsDidChange)) { _ in
            Task {
                await viewModel.reloadAwaited()
                await viewModel.reload()
                await viewModel.loadAwards(viewModel.awardsFormat)
                await viewModel.loadDiscoveries(viewModel.awardsFormat)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task {
                await viewModel.reload()
                await viewModel.loadPicks()
                await viewModel.loadAwards(viewModel.awardsFormat)
                await viewModel.loadDiscoveries(viewModel.awardsFormat)
            }
        }
    }

    private func handle(_ action: DiscoverAction) async {
        switch action {
        case let .openSeries(row): openSeries = row
        case let .openVolume(volume): openVolume = volume
        case let .openAuthor(author): openAuthor = author
        case let .openFriendBook(loved): openFriendBook = loved
        case let .openFriendSaga(loved): openFriendSaga = loved
        case let .openAwaited(edition): openAwaited = edition
        case let .openWinner(winner): openWinner = winner
        case let .openSuggestion(suggestion): openSuggestion = suggestion
        case .openAlerts: showsAlerts = true
        case .refresh:
            async let picks: Void = viewModel.loadPicks()
            await viewModel.loadAll()
            await picks
        case .retry: await viewModel.loadAll()
        }
    }
}

#Preview("Smoke") {
    DiscoverScreen(shelf: .constant(.books), client: .preview, snapshots: .none)
}
