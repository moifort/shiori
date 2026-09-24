import SwiftUI

/// A release date in words: "le 19 févr. 2027", "en mars 2027", "en 2027" — as
/// precisely as it was announced. Dates come as `YYYY`, `YYYY-MM` or
/// `YYYY-MM-DD`, read on the phone's calendar.
enum ReleaseDateText {
    /// The last day a date can mean, to put "2027" after "2027-02-19".
    static func lastDay(_ date: String) -> String {
        switch date.count {
        case 10: date
        case 7: date + "-31"
        default: date + "-12-31"
        }
    }

    /// Whether it is still to come: a day after today, or a month or a year
    /// not over yet — the server's rule.
    static func isUpcoming(_ date: String, today: Date = .now) -> Bool {
        let day = today.formatted(.iso8601.year().month().day())
        return date.count == 10 ? date > day : lastDay(date) >= day
    }

    private static func parts(_ date: String) -> (day: Date, precision: Int)? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts.first
        components.month = parts.count > 1 ? parts[1] : 1
        components.day = parts.count > 2 ? parts[2] : 1
        guard let day = Calendar.current.date(from: components) else { return nil }
        return (day, parts.count)
    }

    /// Under a cover: "8 oct.", "oct. 2026", "2027".
    static func short(_ date: String) -> String {
        guard let (day, precision) = parts(date) else { return date }
        switch precision {
        case 3: return day.formatted(.dateTime.day().month(.abbreviated))
        case 2: return day.formatted(.dateTime.month(.abbreviated).year())
        default: return String(date.prefix(4))
        }
    }

    /// In a sentence: "le 19 févr. 2027", "en mars 2027", "en 2027".
    static func phrase(_ date: String) -> String {
        guard let (day, precision) = parts(date) else { return date }
        switch precision {
        case 3: return String(localized: "le \(day.formatted(.dateTime.day().month(.abbreviated).year()))")
        case 2: return String(localized: "en \(day.formatted(.dateTime.month(.wide).year()))")
        default: return String(localized: "en \(String(date.prefix(4)))")
        }
    }

    /// For a volume not out yet: "Sort le 8 octobre 2026", "Sort en octobre
    /// 2026", "Sort en 2027".
    static func coming(_ date: String) -> String {
        guard let (day, precision) = parts(date) else { return date }
        switch precision {
        case 3: return String(localized: "Sort le \(day.formatted(.dateTime.day().month(.wide).year()))")
        case 2: return String(localized: "Sort en \(day.formatted(.dateTime.month(.wide).year()))")
        default: return String(localized: "Sort en \(String(date.prefix(4)))")
        }
    }
}

/// A release date as a small calendar leaf: the day over the month, or the
/// month over the year, or the year alone — as precisely as it was announced.
struct ReleaseDateBadge: View {
    let date: String

    var body: some View {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        VStack(spacing: 0) {
            Text(verbatim: top(parts)).font(.subheadline.weight(.semibold))
            Text(verbatim: bottom(parts)).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 44)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func month(_ number: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        return (1...12).contains(number) ? symbols[number - 1] : ""
    }

    private func top(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: "\(parts[2])"
        case 2: month(parts[1])
        default: parts.first.map(String.init) ?? ""
        }
    }

    private func bottom(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: month(parts[1])
        case 2: String(parts[0])
        default: ""
        }
    }
}
