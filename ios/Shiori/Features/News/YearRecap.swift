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

    /// Counts what the loaded news holds for the year of `now`: the winners an
    /// award crowned this year, the moves a friend loved, the saga releases and
    /// awaited editions that are already out.
    static func make(
        awards: [AwardWinner],
        events: [FeedEvent],
        releases: [UpcomingRelease],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> YearRecap {
        let year = calendar.component(.year, from: now)
        let today = calendar.startOfDay(for: now)

        func isOut(_ release: UpcomingRelease) -> Bool {
            guard let date = release.date, date.count == 10, let day = release.day(calendar: calendar) else {
                return false
            }
            return calendar.component(.year, from: day) == year && day <= today
        }

        let crowned = awards.filter { $0.mentions.contains { $0.year == year } }
        let loved = events.filter { $0.kind == .loved && calendar.component(.year, from: $0.at) == year }
        let sagas = releases.filter { $0.source == .saga && isOut($0) }
        let awaited = releases.filter { $0.source == .awaited && isOut($0) }

        return YearRecap(tiles: [
            Tile(kind: .awards, count: crowned.count, covers: crowned.prefix(coversShown).map(\.cover)),
            Tile(kind: .friendsFavourites, count: loved.count, covers: loved.prefix(coversShown).map(\.cover)),
            Tile(kind: .seriesReleases, count: sagas.count, covers: sagas.prefix(coversShown).map(\.cover)),
            Tile(kind: .awaitedAvailable, count: awaited.count, covers: awaited.prefix(coversShown).map(\.cover)),
        ])
    }

    static let empty = make(awards: [], events: [], releases: [])
}

extension UpcomingRelease {
    /// The day a full `YYYY-MM-DD` date names; nil on a month or a year alone.
    func day(calendar: Calendar) -> Date? {
        guard let date else { return nil }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
