import Foundation

/// The home dashboard as the app draws it. Books are plain `Book` values so the
/// covers, the sheets and the placeholders are the ones used everywhere else.
struct Dashboard: Codable, Sendable {
    struct YearCount: Identifiable, Hashable, Codable, Sendable {
        var id: Int { year }
        let year: Int
        let count: Int
    }

    struct MonthPages: Identifiable, Hashable, Codable, Sendable {
        var id: Int { month }
        /// 1 for January.
        let month: Int
        let pages: Int
    }

    /// Hours listened, rounded to the hour by the server. Only audiobooks
    /// imported from Audible carry a running time, so a printed library reads
    /// twelve zeros here.
    struct MonthHours: Identifiable, Hashable, Codable, Sendable {
        var id: Int { month }
        /// 1 for January.
        let month: Int
        let hours: Int
    }

    /// This year to date against the same span of last year. No `previous`, no
    /// arrow: a comparison with nothing is not a trend.
    struct Trend: Hashable, Codable, Sendable {
        let current: Int?
        let previous: Int?

        var direction: Direction? {
            guard let current, let previous, current != previous else { return nil }
            return current > previous ? .up : .down
        }

        enum Direction { case up, down }
    }

    /// One segment of the genre bar; a nil genre is the "others" segment.
    struct GenreSlice: Identifiable, Hashable, Codable, Sendable {
        var id: String { genre?.rawValue ?? "others" }
        let genre: BookGenre?
        let count: Int
    }

    struct SeriesProgress: Identifiable, Hashable, Codable, Sendable {
        let id: String
        let name: String
        let readCount: Int
        let totalCount: Int
    }

    let currentYear: Int
    let booksPerYear: [YearCount]
    let pagesPerMonth: [MonthPages]
    let hoursPerMonth: [MonthHours]
    let reading: [Book]
    let suggestions: [Book]
    let lastFinished: Book?
    let pagesPerDay: Trend
    let daysToFinish: Trend
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int
    let genres: [GenreSlice]
    let series: [SeriesProgress]
    /// Books and sagas the reader hearted, together.
    var favoriteCount: Int = 0
    /// Whether a single recording is on the shelf: without one the listening
    /// hours have nothing to chart and the picker leaves them out.
    var hasAudiobooks: Bool = false
    let libraryIsEmpty: Bool
}

extension Date {
    /// Whole calendar days from this date to `now`, in the device calendar: a book
    /// started last night at 23:00 was started one day ago this morning.
    func daysAgo(from now: Date = .now) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: self),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, days)
    }
}
