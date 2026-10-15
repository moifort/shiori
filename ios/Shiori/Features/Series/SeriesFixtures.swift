#if DEBUG
import Foundation

/// The sagas of the App Store showcase, for the previews and the tests.
enum SeriesFixtures {
    static let followed: [FollowedSeries] =
        Showcase.seriesPage(limit: 6, after: nil, mode: .all, state: nil).items

    /// The first saga of the showcase, as its page is drawn.
    static var screen: SeriesScreenData { Showcase.seriesScreen(id: followed[0].seriesId) }
}

extension SeriesClient {
    /// Answers from the showcase library and accepts every write.
    static let preview = SeriesClient(
        screen: { id, _, _ in Showcase.seriesScreen(id: id) },
        friendScreen: { _, id, _ in (Showcase.seriesScreen(id: id).series, nil) },
        releases: { id, _ in Showcase.sagaReleases(seriesId: id) },
        lookUpReleases: { id, _ in Showcase.sagaReleases(seriesId: id) },
        rate: { id, stars in SeriesOpinion(seriesId: id, rating: stars, favorite: false) },
        removeRating: { id in SeriesOpinion(seriesId: id, rating: nil, favorite: false) },
        setFollowed: { id, followed, _ in
            var opinion = SeriesOpinion(seriesId: id)
            opinion.followed = followed
            return opinion
        },
        setFavorite: { id, favorite in SeriesOpinion(seriesId: id, rating: nil, favorite: favorite) },
        declareVolumeCount: { id, _ in SeriesOpinion(seriesId: id, rating: nil, favorite: false) },
        refresh: { id, _ in Showcase.seriesScreen(id: id).series },
        delete: { _, _ in },
        mergeCandidates: { SeriesFixtures.followed },
        merge: { _, _, _ in },
        updateBook: { _, _ in .preview },
        setStatus: { _, _ in .preview },
        addAudibleVolume: { _, _, _ in .preview },
        addBook: { _, _ in .preview },
        subgenres: { [] },
        page: { limit, after, mode, state in
            Showcase.seriesPage(limit: limit, after: after, mode: mode, state: state)
        },
        followedRow: { id, _ in SeriesFixtures.followed.first { $0.seriesId == id } }
    )
}
#endif
