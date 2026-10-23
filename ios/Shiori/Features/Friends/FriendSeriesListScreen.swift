import SwiftUI

/// A friend's sagas, connected: loads a page per view and filter, takes a
/// saga's first volume onto the reader's pile, opens a saga as a sheet, and
/// hands the rest to `FriendSeriesListPage`.
struct FriendSeriesListScreen: View {
    let friendId: String
    let friendName: String
    /// The reader's own sagas, previewed: every one is theirs already.
    var isPreview = false
    var client: FriendsClient = .live

    @State private var model = FriendShelfListModel<FriendSaga>(ownedFlag: \.inLibrary)
    @State private var mode: LibraryMode = .all
    @State private var state: SeriesState?
    @State private var openSaga: FriendSaga?

    var body: some View {
        FriendSeriesListPage(
            friendName: friendName,
            sagas: model.rows,
            mode: $mode,
            state: $state,
            isWaiting: model.loadedQuery != query && model.errorMessage == nil,
            loadFailed: model.loadedQuery != query || model.rows.isEmpty ? model.errorMessage : nil,
            hasMore: model.hasMore,
            loadMoreFailed: model.loadMoreFailed,
            adding: model.adding,
            isPreview: isPreview
        ) { action in
            switch action {
            case let .openSaga(saga): openSaga = saga
            case let .take(saga, format):
                guard let first = saga.volumes.first else { return }
                await model.take(saga.id) {
                    try await client.addBook(friendId, first.id, .toRead, format)
                }
            case .loadMore: await model.loadMore(fetch: fetch)
            case .refresh: await model.load(query: query, fetch: fetch)
            }
        }
        .task(id: query) { await model.load(query: query, fetch: fetch) }
        // Pushed, as a saga opens from the reader's own Series tab.
        .pushesDetail(item: $openSaga) { saga in
            // Where the saga stands is the friend's; previewed, the reader's
            // own saga opens as it does from their Series tab.
            SeriesScreen(
                seriesId: saga.seriesId,
                language: saga.language,
                friend: isPreview ? nil : SeriesFriend(id: friendId, name: friendName)
            )
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { model.addFailed != nil }, set: { if !$0 { model.addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { model.addFailed = nil }
        } message: {
            Text(model.addFailed ?? "")
        }
    }

    private var query: String { "\(mode.rawValue)-\(state?.rawValue ?? "all")" }

    private var fetch: FriendShelfListModel<FriendSaga>.Fetch {
        let (client, friendId, state, loved) = (client, friendId, state, mode == .favorites)
        return { after in
            let page = try await client.sagaPage(friendId, state, loved, after)
            return (page.sagas, page.hasMore)
        }
    }
}
