import Foundation

/// How far ahead the list looks, from today: everything announced, the next
/// three months, or the next six.
enum ReleaseHorizon: String, CaseIterable, Identifiable, Sendable {
    case all, threeMonths, sixMonths
    var id: String { rawValue }
}

/// One line of the list: a day with what is out on it, or a label standing
/// where a day cannot ("2027", "Sans date").
struct ReleaseDay: Identifiable, Hashable, Sendable {
    let id: String
    /// "mer." above the number; nil when the label is not a day.
    let weekday: String?
    let label: String
    let releases: [UpcomingRelease]
}

/// A month of the list, its days in date order.
struct ReleaseMonthSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let days: [ReleaseDay]
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

    /// The list for a horizon, a month at a time. A release already out is not
    /// in it; what is dated to a year alone, or not at all, closes "Tout".
    func sections(for horizon: ReleaseHorizon) -> [ReleaseMonthSection] {
        let today = calendar.startOfDay(for: now)
        let end: Date? = switch horizon {
        case .threeMonths: calendar.date(byAdding: .month, value: 3, to: today)
        case .sixMonths: calendar.date(byAdding: .month, value: 6, to: today)
        case .all: nil
        }
        var months: [String: (start: Date, days: [Int: [UpcomingRelease]], monthOnly: [UpcomingRelease])] = [:]
        var years: [Int: [UpcomingRelease]] = [:]
        var undated: [UpcomingRelease] = []
        for release in releases {
            guard let date = parsed(release.date) else {
                if horizon == .all { undated.append(release) }
                continue
            }
            guard let month = date.month else {
                if horizon == .all, date.year >= current.year { years[date.year, default: []].append(release) }
                continue
            }
            guard let start = calendar.date(from: DateComponents(year: date.year, month: month, day: 1)),
                let next = calendar.date(byAdding: .month, value: 1, to: start)
            else { continue }
            if let day = date.day {
                guard let when = calendar.date(from: DateComponents(year: date.year, month: month, day: day)),
                    when >= today, end.map({ when <= $0 }) ?? true
                else { continue }
                let key = String(format: "%04d-%02d", date.year, month)
                months[key, default: (start, [:], [])].days[day, default: []].append(release)
            } else {
                guard next > today, end.map({ start <= $0 }) ?? true else { continue }
                let key = String(format: "%04d-%02d", date.year, month)
                months[key, default: (start, [:], [])].monthOnly.append(release)
            }
        }
        var sections = months.keys.sorted().compactMap { key -> ReleaseMonthSection? in
            guard let entry = months[key] else { return nil }
            let parts = key.split(separator: "-").compactMap { Int($0) }
            var days = entry.days.keys.sorted().map { day -> ReleaseDay in
                let when = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: day))
                return ReleaseDay(
                    id: "\(key)-\(day)",
                    weekday: when?.formatted(.dateTime.weekday(.abbreviated)),
                    label: String(day),
                    releases: entry.days[day] ?? []
                )
            }
            if !entry.monthOnly.isEmpty {
                days.append(ReleaseDay(id: "\(key)-month", weekday: nil, label: String(localized: "Sans jour"), releases: entry.monthOnly))
            }
            var title = entry.start.formatted(.dateTime.month(.wide)).capitalized
            if parts[0] != current.year { title += " \(parts[0])" }
            return ReleaseMonthSection(id: key, title: title, days: days)
        }
        var beyond = years.keys.sorted().map { year in
            ReleaseDay(id: "year-\(year)", weekday: nil, label: String(year), releases: years[year] ?? [])
        }
        if !undated.isEmpty {
            beyond.append(ReleaseDay(id: "undated", weekday: nil, label: String(localized: "Sans date"), releases: undated))
        }
        if !beyond.isEmpty {
            sections.append(ReleaseMonthSection(id: "beyond", title: String(localized: "Au-delà"), days: beyond))
        }
        return sections
    }
}
