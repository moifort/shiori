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

    var title: String { month?.title ?? String(localized: "Sans date") }

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
}
