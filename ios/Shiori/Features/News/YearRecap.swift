import Foundation

/// The year so far, as the feed's first block counts it: the prizes of the
/// year, what the reader's friends loved, what the favourite series put out,
/// and the awaited books that are now out. Four tiles, always, so an empty one
/// says what is still to come.
struct YearRecap: Hashable, Sendable {
    enum Kind: CaseIterable, Hashable, Sendable {
        case awards, friendsFavourites, seriesReleases, awaitedAvailable
    }

    struct Tile: Identifiable, Hashable, Sendable {
        let kind: Kind
        let count: Int
        /// The first covers the tile lets out of its corner.
        let covers: [Book]
        var id: Kind { kind }
    }

    let tiles: [Tile]

    /// How many covers a tile shows.
    static let coversShown = 2

    /// Counts the news for the year of `now`: the winners an award crowned this
    /// year, the moves a friend loved, and `released`, what the server says came
    /// out this year.
    static func make(
        awards: [AwardWinner],
        events: [FeedEvent],
        released: [UpcomingRelease],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearRecap {
        let year = calendar.component(.year, from: now)
        let crowned = awards.filter { $0.mentions.contains { $0.year == year } }
        let loved = events.filter { $0.kind == .loved && calendar.component(.year, from: $0.at) == year }
        let sagas = released.filter { $0.source == .saga }
        let awaited = released.filter { $0.source == .awaited }

        return YearRecap(tiles: [
            Tile(kind: .awards, count: crowned.count, covers: crowned.prefix(coversShown).map(\.cover)),
            Tile(kind: .friendsFavourites, count: loved.count, covers: loved.prefix(coversShown).map(\.cover)),
            Tile(kind: .seriesReleases, count: sagas.count, covers: sagas.prefix(coversShown).map(\.cover)),
            Tile(kind: .awaitedAvailable, count: awaited.count, covers: awaited.prefix(coversShown).map(\.cover)),
        ])
    }

    static let empty = make(awards: [], events: [], released: [])
}
