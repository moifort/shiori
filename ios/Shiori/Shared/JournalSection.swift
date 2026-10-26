import Foundation

/// The headings a shelf ordered newest first is cut under, as a journal reads
/// back: "Aujourd'hui", "Hier", "Cette semaine", "La semaine dernière", "Plus
/// tôt en octobre", then one month each — "Septembre", "Janvier 2025" once the
/// year is another.
enum JournalPeriod: Hashable {
    case today, yesterday, thisWeek, lastWeek, earlierThisMonth
    case month(ShelfMonth)

    init(_ date: Date, now: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week) ?? week
        let month = calendar.dateInterval(of: .month, for: today)?.start ?? today
        if day >= today { self = .today }
        else if calendar.date(byAdding: .day, value: 1, to: day) == today { self = .yesterday }
        else if day >= week { self = .thisWeek }
        else if day >= lastWeek { self = .lastWeek }
        else if day >= month { self = .earlierThisMonth }
        else { self = .month(ShelfMonth(date, calendar: calendar)) }
    }

    func title(now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .today: return String(localized: "Aujourd'hui")
        case .yesterday: return String(localized: "Hier")
        case .thisWeek: return String(localized: "Cette semaine")
        case .lastWeek: return String(localized: "La semaine dernière")
        case .earlierThisMonth:
            let name = now.formatted(.dateTime.month(.wide))
            return String(localized: "Plus tôt en \(name)")
        case let .month(month):
            let date = calendar.date(from: DateComponents(year: month.year, month: month.month)) ?? now
            let name = month.year == calendar.component(.year, from: now)
                ? date.formatted(.dateTime.month(.wide))
                : date.formatted(.dateTime.month(.wide).year())
            return name.prefix(1).uppercased() + name.dropFirst()
        }
    }
}

extension ListSection {
    /// The rows cut into journal periods, in the order given: newest first.
    static func byPeriod(
        _ rows: [Row],
        on date: (Row) -> Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ListSection<Row>] {
        var sections: [ListSection<Row>] = []
        var current: JournalPeriod?
        var runs: [String: Int] = [:]
        for row in rows {
            let period = date(row).map { JournalPeriod($0, now: now, calendar: calendar) }
            if let last = sections.indices.last, period == current {
                sections[last].rows.append(row)
                continue
            }
            current = period
            let title = period?.title(now: now, calendar: calendar) ?? String(localized: "Sans date")
            let run = runs[title, default: 0]
            runs[title] = run + 1
            sections.append(ListSection(id: "\(title)#\(run)", title: title, rows: [row]))
        }
        return sections
    }

    /// The rows cut wherever the year changes: "2026", "2025".
    static func byYear(_ rows: [Row], on date: (Row) -> Date?, calendar: Calendar = .current) -> [ListSection<Row>] {
        var sections: [ListSection<Row>] = []
        for row in rows {
            let title = date(row).map { String(calendar.component(.year, from: $0)) } ?? String(localized: "Sans date")
            if let last = sections.indices.last, sections[last].title == title {
                sections[last].rows.append(row)
            } else {
                sections.append(ListSection(id: "\(title)#\(sections.count)", title: title, rows: [row]))
            }
        }
        return sections
    }
}
