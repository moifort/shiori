import Foundation

/// The home dashboard as the app draws it. Books are plain `Book` values so the
/// covers, the sheets and the placeholders are the ones used everywhere else.
struct Dashboard: Sendable {
    struct YearCount: Identifiable, Hashable, Sendable {
        var id: Int { year }
        let year: Int
        let count: Int
    }

    struct MonthPages: Identifiable, Hashable, Sendable {
        var id: Int { month }
        /// 1 for January.
        let month: Int
        let pages: Int
    }

    /// This year to date against the same span of last year. No `previous`, no
    /// arrow: a comparison with nothing is not a trend.
    struct Trend: Hashable, Sendable {
        let current: Int?
        let previous: Int?

        var direction: Direction? {
            guard let current, let previous, current != previous else { return nil }
            return current > previous ? .up : .down
        }

        enum Direction { case up, down }
    }

    /// One segment of the genre bar; a nil genre is the "others" segment.
    struct GenreSlice: Identifiable, Hashable, Sendable {
        var id: String { genre?.rawValue ?? "others" }
        let genre: BookGenre?
        let count: Int
    }

    struct SeriesProgress: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let readCount: Int
        let totalCount: Int
    }

    let currentYear: Int
    let booksPerYear: [YearCount]
    let pagesPerMonth: [MonthPages]
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
