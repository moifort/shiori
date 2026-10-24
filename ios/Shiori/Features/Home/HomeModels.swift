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

    /// One segment of the genre bar; a nil genre is the "others" segment.
    struct GenreSlice: Identifiable, Hashable, Codable, Sendable {
        var id: String { genre?.rawValue ?? "others" }
        let genre: BookGenre?
        let count: Int
    }

    struct SeriesProgress: Identifiable, Hashable, Codable, Sendable {
        let id: String
        let name: String
        /// The saga heard rather than read, measured on its recordings.
        var isAudio: Bool = false
        let readCount: Int
        let totalCount: Int
        /// The reader's rating of the saga, else the average of the volumes
        /// they rated, rounded to the half star drawn. Nil when they rated
        /// neither.
        var rating: Double?
        /// A hearted saga, drawn as the heart, which is five stars.
        var favorite: Bool = false
        /// The cover of the volume shelved last, which the saga is drawn with.
        var coverURL: URL?
    }

    let currentYear: Int
    let booksPerYear: [YearCount]
    let pagesPerMonth: [MonthPages]
    let hoursPerMonth: [MonthHours]
    let reading: [Book]
    /// The pile, the book shelved last first, a dozen at most.
    var toRead: [Book] = []
    let lastFinished: Book?
    let toReadCount: Int
    /// Every book finished since the first, whatever the year.
    var readCount: Int = 0
    /// The pages of every book finished, whatever the year.
    var pagesRead: Int = 0
    /// The hours of every recording finished, whatever the year.
    var hoursListened: Int = 0
    let genres: [GenreSlice]
    let series: [SeriesProgress]
    /// Books and sagas the reader hearted, together.
    var favoriteCount: Int = 0
    /// Whether a single recording is on the shelf: without one the listening
    /// hours have nothing to chart and the picker leaves them out.
    var hasAudiobooks: Bool = false
    /// The same for the pages: a library of recordings only has none to chart.
    var hasPrintedBooks: Bool = true
    let libraryIsEmpty: Bool
}

extension Dashboard {
    /// The books finished this year: the last bar of the chart.
    var readThisYear: Int {
        booksPerYear.first { $0.year == currentYear }?.count ?? 0
    }

    /// The pages of the books finished this year, the months summed.
    var pagesThisYear: Int {
        pagesPerMonth.reduce(0) { $0 + $1.pages }
    }

    /// The hours of the recordings finished this year, the months summed.
    var hoursThisYear: Int {
        hoursPerMonth.reduce(0) { $0 + $1.hours }
    }
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
