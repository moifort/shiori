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
        screen: { id, _ in Showcase.seriesScreen(id: id) },
        catalogue: { id, _ in Showcase.seriesScreen(id: id).series },
        friendScreen: { _, id in (Showcase.seriesScreen(id: id).series, nil) },
        releases: { id in Showcase.sagaReleases(seriesId: id) },
        lookUpReleases: { id in Showcase.sagaReleases(seriesId: id) },
        rate: { id, stars in SeriesOpinion(seriesId: id, rating: stars, favorite: false) },
        removeRating: { id in SeriesOpinion(seriesId: id, rating: nil, favorite: false) },
        setFollowed: { id, followed in
            var opinion = SeriesOpinion(seriesId: id)
            opinion.followed = followed
            return opinion
        },
        setFavorite: { id, favorite in SeriesOpinion(seriesId: id, rating: nil, favorite: favorite) },
        declareVolumeCount: { id, _ in SeriesOpinion(seriesId: id, rating: nil, favorite: false) },
        delete: { _ in },
        mergeCandidates: { SeriesFixtures.followed },
        merge: { _, _ in },
        updateBook: { _, _ in .preview },
        setStatus: { _, _ in .preview },
        addAudibleVolume: { _, _ in .preview },
        addBook: { _, _ in .preview },
        subgenres: { [] },
        page: { limit, after in
            Showcase.seriesPage(limit: limit, after: after, mode: .all, state: nil)
        },
        followedRow: { id in SeriesFixtures.followed.first { $0.seriesId == id } }
    )
}
#endif
