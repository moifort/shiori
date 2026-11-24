import SwiftUI

/// A friend's "Séries", connected: the reader's own "Séries" reduced to
/// "Toutes les séries" — the cards two by row — under the filters of their
/// "Livres": the format pills, and the status menu in the corner. Every page
/// is loaded at once, as the reader's sagas are. A card opens the saga as a
/// friend's: where they stand on it.
///
/// The cards say what the friend's own volumes say, never the shared
/// catalogue: "5 sur 5 lus" counts the volumes on their shelf.
struct FriendSeriesListScreen: View {
    let friendId: String
    let friendName: String
    var client: FriendsClient = .live

    @State private var sagas: [FollowedSeries] = []
    @State private var loaded = false
    @State private var errorMessage: String?
    @State private var status: SeriesStatusFilter = .all
    @State private var format: BookFormat?
    @State private var openSaga: SeriesDestinationID?

    /// The most pages asked for, as the reader's own sagas.
    private static let maxPages = 10

    var body: some View {
        SeriesShelfPage(
            upNext: [],
            releases: [],
            filters: [],
            filter: .all,
            series: sagas.filter { saga in status.keeps(saga) && (format.map { saga.heldFormat == $0 } ?? true) },
            isLoading: !loaded && errorMessage == nil,
            errorMessage: errorMessage,
            statuses: SeriesStatusFilter.allCases,
            selectedStatus: status,
            formats: BookFormat.allCases.filter { f in sagas.contains { $0.heldFormat == f } },
            selectedFormat: format
        ) { action in
            switch action {
            case let .openSeries(saga): openSaga = SeriesDestinationID(id: saga.seriesId)
            case let .selectStatus(status): withAnimation(.smooth) { self.status = status }
            case let .selectFormat(format): withAnimation(.smooth) { self.format = format }
            case .refresh: Task { await load() }
            case .openBook, .openVolume, .follow, .selectFilter: break
            }
        }
        .overlay {
            if loaded, sagas.isEmpty {
                EmptyState(
                    systemImage: "square.stack",
                    title: "Aucune série",
                    message: "Aucune série n'a été ajoutée à cette bibliothèque."
                )
            }
        }
        .scrollAwayBar(String(localized: "Séries"))
        .pushesDetail(item: $openSaga) { saga in
            SeriesScreen(seriesId: saga.id, friend: SeriesFriend(id: friendId, name: friendName))
        }
        .task { if !loaded { await load() } }
    }

    private func load() async {
        errorMessage = nil
        do {
            var all: [FriendSaga] = []
            var after: String?
            for _ in 0..<Self.maxPages {
                let page = try await client.sagaPage(friendId, nil, false, after)
                all += page.sagas.filter { new in !all.contains { $0.id == new.id } }
                guard page.hasMore, let last = page.sagas.last else { break }
                after = last.id
            }
            sagas = all.map(FollowedSeries.init(friendSaga:))
            loaded = true
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }
}

extension FollowedSeries {
    /// A friend's saga as the Series tab's card reads it: their volumes on the
    /// strip and nothing between them, their heart and their stars.
    init(friendSaga saga: FriendSaga) {
        self.init(
            seriesId: saga.seriesId,
            name: saga.name,
            isAudio: saga.isAudio,
            author: saga.author,
            language: saga.language,
            state: saga.state,
            genre: saga.genre,
            ownedCount: saga.ownedCount,
            shelvedAt: saga.shelvedAt,
            volumes: saga.volumes,
            strip: saga.volumes.map(SeriesStripItem.owned),
            opinion: SeriesOpinion(seriesId: saga.seriesId, rating: saga.rating, favorite: saga.favorite)
        )
    }
}

#Preview {
    NavigationStack {
        FriendSeriesListScreen(friendId: "camille", friendName: "Camille", client: .preview)
    }
}
