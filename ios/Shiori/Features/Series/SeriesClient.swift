import Foundation

/// What a saga's screen is drawn from in one request.
typealias SeriesScreenData = (series: BookSeries?, opinion: SeriesOpinion?, owned: [Book])

/// Everything the saga screens ask of the server, as closures: `.live` goes
/// through `SeriesAPI` and its neighbours, a test builds the one it needs.
struct SeriesClient: Sendable {
    var screen: @Sendable (_ id: String, SeriesProposal?) async throws -> SeriesScreenData
    /// The catalogue the AI builds for a saga the screen found awaiting one.
    var catalogue: @Sendable (_ id: String, SeriesProposal?) async throws -> BookSeries?
    /// A saga opened from a friend's shelf: the catalogue, and where they stand.
    var friendScreen: @Sendable (_ friendId: String, _ seriesId: String)
        async throws -> (series: BookSeries?, saga: FriendSaga?)
    var releases: @Sendable (_ seriesId: String) async throws -> SagaReleases
    /// Looks the saga up on the web in an edition nobody watched yet.
    var lookUpReleases: @Sendable (_ seriesId: String) async throws -> SagaReleases
    var rate: @Sendable (_ seriesId: String, _ stars: Double) async throws -> SeriesOpinion
    var removeRating: @Sendable (_ seriesId: String) async throws -> SeriesOpinion
    var setFollowed: @Sendable (_ seriesId: String, Bool) async throws -> SeriesOpinion
    var setFavorite: @Sendable (_ seriesId: String, Bool) async throws -> SeriesOpinion
    var declareVolumeCount: @Sendable (_ seriesId: String, Int) async throws -> SeriesOpinion
    var delete: @Sendable (_ seriesId: String) async throws -> Void
    var mergeCandidates: @Sendable () async throws -> [FollowedSeries]
    var merge: @Sendable (_ seriesId: String, _ into: String) async throws -> Void
    /// One volume corrected; the server carries a genre to every volume.
    var updateBook: @Sendable (_ id: String, BookCorrection) async throws -> Book
    var setStatus: @Sendable (_ id: String, ReadingStatus) async throws -> Book
    /// Audible's own record of a volume, through the reader's account.
    var addAudibleVolume: @Sendable (_ seriesId: String, _ volume: Int) async throws -> Book
    /// "Look the book up, then add it".
    var addBook: @Sendable (BookDraft, BookAddition.LookUp?) async throws -> Book
    var subgenres: @Sendable () async throws -> [String]
    /// One page of the Series tab after the given cursor, in the server's order.
    var page: @Sendable (_ limit: Int, _ after: String?, LibraryMode, SeriesState?)
        async throws -> CursorPage<FollowedSeries>
    /// One row of the Series tab, read again after a change.
    var followedRow: @Sendable (_ seriesId: String) async throws -> FollowedSeries?
}

extension SeriesClient {
    static let live = SeriesClient(
        screen: { try await SeriesAPI.screen(id: $0, proposal: $1) },
        catalogue: { try await SeriesAPI.catalogue(id: $0, proposal: $1) },
        friendScreen: { try await FriendsAPI.sagaScreen(friendId: $0, seriesId: $1) },
        releases: { try await DiscoverAPI.sagaReleases(seriesId: $0) },
        lookUpReleases: { try await DiscoverAPI.lookUpSaga(seriesId: $0) },
        rate: { try await SeriesAPI.rate(seriesId: $0, stars: $1) },
        removeRating: { try await SeriesAPI.removeRating(seriesId: $0) },
        setFollowed: { try await SeriesAPI.setFollowed(seriesId: $0, followed: $1) },
        setFavorite: { try await SeriesAPI.setFavorite(seriesId: $0, favorite: $1) },
        declareVolumeCount: { try await SeriesAPI.declareVolumeCount(seriesId: $0, count: $1) },
        delete: { _ = try await SeriesAPI.delete(seriesId: $0) },
        mergeCandidates: { try await SeriesAPI.mergeCandidates() },
        merge: { _ = try await SeriesAPI.merge(seriesId: $0, into: $1) },
        updateBook: { try await BookAPI.update(id: $0, correction: $1) },
        setStatus: { try await BookAPI.setStatus(id: $0, status: $1) },
        addAudibleVolume: { try await SeriesAPI.addAudibleVolume(seriesId: $0, volume: $1) },
        addBook: { try await BookAddition.add($0, lookingUp: $1, source: .series) },
        subgenres: { try await BookAPI.subgenres() },
        page: { try await SeriesAPI.mySeriesPage(limit: $0, after: $1, mode: $2, state: $3) },
        followedRow: { try await SeriesAPI.followedSeries(seriesId: $0) }
    )
}
