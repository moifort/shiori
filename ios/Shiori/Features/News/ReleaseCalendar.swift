import Foundation

/// How far ahead the calendar looks: the month, the six months, or past them.
enum ReleaseHorizon: String, CaseIterable, Identifiable, Sendable {
    case month, sixMonths, later
    var id: String { rawValue }
}

/// One month of the calendar: its grid, and the releases that fall in it.
struct ReleaseMonth: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Blank cells before the 1st, the week starting on Monday.
    let leadingBlanks: Int
    let dayCount: Int
    /// The releases dated to the day, by day of the month.
    let byDay: [Int: [UpcomingRelease]]
    /// The releases announced for the month with no day.
    let monthOnly: [UpcomingRelease]

    var all: [UpcomingRelease] {
        byDay.keys.sorted().flatMap { byDay[$0] ?? [] } + monthOnly
    }
}

/// The releases of one year past the six months, in date order.
struct ReleaseYear: Identifiable, Hashable, Sendable {
    struct Row: Identifiable, Hashable, Sendable {
        let release: UpcomingRelease
        /// "juin", when the month is announced.
        let month: String?
        var id: String { release.id }
    }

    let year: Int
    let rows: [Row]
    var id: Int { year }
}

/// The upcoming releases laid on a calendar, from `now`. Pure: the same
/// releases and the same day always give the same grid.
struct ReleaseCalendar: Sendable {
    let releases: [UpcomingRelease]
    let now: Date
    var calendar: Calendar = .current

    private struct Parsed {
        let year: Int
        let month: Int?
        let day: Int?
    }

    private func parsed(_ date: String?) -> Parsed? {
        guard let date else { return nil }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard let year = parts.first else { return nil }
        return Parsed(year: year, month: parts.count > 1 ? parts[1] : nil, day: parts.count > 2 ? parts[2] : nil)
    }

    private var current: (year: Int, month: Int) {
        (calendar.component(.year, from: now), calendar.component(.month, from: now))
    }

    /// Months from the current one: 0 for this month, nil for a year with no month.
    private func offset(of parsed: Parsed) -> Int? {
        guard let month = parsed.month else { return nil }
        return (parsed.year - current.year) * 12 + (month - current.month)
    }

    /// The month `offset` months from now, with what falls in it.
    func month(offset: Int) -> ReleaseMonth {
        let start = calendar.date(
            from: DateComponents(year: current.year, month: current.month + offset, day: 1)
        ) ?? now
        let components = calendar.dateComponents([.year, .month], from: start)
        let inMonth = releases.filter { release in
            guard let date = parsed(release.date), let shifted = self.offset(of: date) else { return false }
            return shifted == offset
        }
        let dated = Dictionary(grouping: inMonth.filter { parsed($0.date)?.day != nil }) {
            parsed($0.date)?.day ?? 0
        }
        let weekday = calendar.component(.weekday, from: start)
        return ReleaseMonth(
            id: String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0),
            name: start.formatted(.dateTime.month(.wide)).capitalized,
            leadingBlanks: (weekday + 5) % 7,
            dayCount: calendar.range(of: .day, in: .month, for: start)?.count ?? 30,
            byDay: dated,
            monthOnly: inMonth.filter { parsed($0.date)?.day == nil }
        )
    }

    var thisMonth: ReleaseMonth { month(offset: 0) }

    /// This month and the five after it, for the months overview.
    var sixMonths: [ReleaseMonth] { (0..<6).map { month(offset: $0) } }

    /// What is announced past the six months, a year at a time: a release
    /// dated to a year alone, or to a month beyond the sixth.
    var later: [ReleaseYear] {
        let rows = releases.compactMap { release -> (Int, Int, ReleaseYear.Row)? in
            guard let date = parsed(release.date) else { return nil }
            if let shifted = offset(of: date) {
                guard shifted >= 6, let month = date.month else { return nil }
                let name = calendar.date(from: DateComponents(year: date.year, month: month, day: 1))
                    .map { $0.formatted(.dateTime.month(.wide)) }
                return (date.year, month, .init(release: release, month: name))
            }
            guard date.year >= current.year else { return nil }
            return (date.year, 13, .init(release: release, month: nil))
        }
        return Dictionary(grouping: rows, by: \.0)
            .map { year, rows in
                ReleaseYear(year: year, rows: rows.sorted { $0.1 < $1.1 }.map(\.2))
            }
            .sorted { $0.year < $1.year }
    }

    /// Announced, and never dated.
    var undated: [UpcomingRelease] { releases.filter { parsed($0.date) == nil } }

    /// The day to open on: today when something is out on it, else the first
    /// day of the month that has a release, else today.
    func initialDay(in month: ReleaseMonth) -> Int {
        let today = calendar.component(.day, from: now)
        if month.byDay[today] != nil { return today }
        return month.byDay.keys.sorted().first(where: { $0 >= today }) ?? month.byDay.keys.min() ?? today
    }

    /// "Mercredi 4 novembre".
    func dayTitle(_ day: Int, in month: ReleaseMonth) -> String {
        let parts = month.id.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
            let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: day))
        else { return "\(day) \(month.name)" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }
}
