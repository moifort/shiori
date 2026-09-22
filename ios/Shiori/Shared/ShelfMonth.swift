import Foundation

/// The month a row of the Library or Series tab is filed under, as Vinarium
/// heads its wine list: "Septembre 2026". The server orders both lists newest
/// first on the date it shelves each row on; the app only cuts where the month
/// changes.
struct ShelfMonth: Hashable {
    let year: Int
    let month: Int

    init(_ date: Date, calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    /// "Septembre 2026", capitalized: a French month name is lowercase inside a
    /// sentence, but this one stands alone as a heading.
    var title: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? .now
        let raw = Self.formatter.string(from: date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()
}

/// One month of rows, cut out of a list the server already ordered.
struct MonthSection<Row>: Identifiable {
    /// The position, not the month: a month is unique only as long as the
    /// server keeps its promise of one run per month, and a duplicate id is a
    /// list that draws the wrong rows.
    let id: Int
    /// Nil for rows that carry no date, which only a stale snapshot can hold.
    let month: ShelfMonth?
    var rows: [Row]
    /// A heading that is not a month: the rated view cuts its rows by stars.
    var heading: String?

    var title: String { heading ?? month?.title ?? String(localized: "Sans date") }

    /// Cuts `rows` wherever the month changes from one row to the next, so a
    /// page that lands extends the last section rather than opening a second
    /// one under the same heading.
    static func cut(_ rows: [Row], on date: (Row) -> Date?) -> [MonthSection<Row>] {
        var sections: [MonthSection<Row>] = []
        for row in rows {
            let month = date(row).map { ShelfMonth($0) }
            if let last = sections.last, last.month == month {
                sections[sections.count - 1].rows.append(row)
            } else {
                sections.append(MonthSection(id: sections.count, month: month, rows: [row]))
            }
        }
        return sections
    }

    /// Cuts `rows` wherever the number of stars changes from one row to the
    /// next, for a list the server ordered best first: "5 étoiles", "4
    /// étoiles"… A row with no stars, which only a stale snapshot can hold,
    /// goes under a dateless heading.
    static func cutByStars(_ rows: [Row], on stars: (Row) -> Int?) -> [MonthSection<Row>] {
        var sections: [MonthSection<Row>] = []
        var lastStars: Int?? = .none
        for row in rows {
            let current = stars(row)
            if let last = lastStars, last == current {
                sections[sections.count - 1].rows.append(row)
            } else {
                let heading = current.map { count in
                    count == 1 ? String(localized: "1 étoile") : String(localized: "\(count) étoiles")
                }
                sections.append(MonthSection(id: sections.count, month: nil, rows: [row], heading: heading))
                lastStars = .some(current)
            }
        }
        return sections
    }
}
