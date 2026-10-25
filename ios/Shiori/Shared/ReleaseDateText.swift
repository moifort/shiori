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

    /// How long until it comes out: "1 jour", "10 jours", "2 mois", "1 an" — in days under a month, months under a year. Nil for a
    /// date given only as a year, or one not ahead any more.
    static func countdown(_ date: String, today: Date = .now) -> String? {
        guard let (day, precision) = parts(date), precision > 1 else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let span = calendar.dateComponents([.day, .month, .year], from: start, to: day)
        guard let days = calendar.dateComponents([.day], from: start, to: day).day, days > 0
        else { return nil }
        let components: DateComponents =
            if days < 30 { DateComponents(day: days) }
            else if let years = span.year, years > 0 { DateComponents(year: years) }
            else { DateComponents(month: max(span.month ?? 1, 1)) }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: components)
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

    /// For a work already out: "Sorti le 16 septembre 2026", "Sorti en août
    /// 2026", "Sorti en 2026".
    static func out(_ date: String) -> String {
        guard let (day, precision) = parts(date) else { return date }
        switch precision {
        case 3: return String(localized: "Sorti le \(day.formatted(.dateTime.day().month(.wide).year()))")
        case 2: return String(localized: "Sorti en \(day.formatted(.dateTime.month(.wide).year()))")
        default: return String(localized: "Sorti en \(String(date.prefix(4)))")
        }
    }
}

/// A release date as a small calendar leaf: the day over the month, or the
/// month over the year, or the year alone — as precisely as it was announced.
/// One square whatever it says, so the badges line up down a list.
struct ReleaseDateBadge: View {
    let date: String
    /// On Liquid Glass, in white with the month dimmed over a soft inner
    /// glow, ringed in white: over a card's own colours.
    var onGlass = false

    var body: some View {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        let leaf = VStack(spacing: onGlass ? 1 : 0) {
            Text(verbatim: top(parts))
                .font(onGlass ? .headline.weight(.bold) : .subheadline.weight(.semibold))
            if let bottom = bottom(parts) {
                Text(verbatim: bottom)
                    .font(onGlass ? .caption2.weight(.semibold) : .caption2)
                    .foregroundStyle(onGlass ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(width: 48, height: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ReleaseDateText.phrase(date)))
        if onGlass {
            leaf
                .foregroundStyle(.white)
                .background {
                    // A soft glow inside the leaf, behind the date.
                    RadialGradient(
                        colors: [.white.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                    .clipShape(.rect(cornerRadius: 10))
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 1))
        } else {
            leaf.overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }

    private func month(_ number: Int) -> String {
        let symbols = onGlass ? Self.clippedMonths : Calendar.current.shortMonthSymbols
        return (1...12).contains(number) ? symbols[number - 1] : ""
    }

    /// The months cut to three letters without their dot, so they breathe in
    /// the glass leaf — four where three would read as another month
    /// ("juin", "juil").
    private static let clippedMonths: [String] = {
        let bare = Calendar.current.shortMonthSymbols.map { $0.replacingOccurrences(of: ".", with: "") }
        let three = bare.map { String($0.prefix(3)) }
        return bare.indices.map { index in
            three.filter { $0 == three[index] }.count > 1 ? String(bare[index].prefix(4)) : three[index]
        }
    }()

    private func top(_ parts: [Int]) -> String {
        switch parts.count {
        case 3: "\(parts[2])"
        case 2: month(parts[1])
        default: parts.first.map(String.init) ?? ""
        }
    }

    private func bottom(_ parts: [Int]) -> String? {
        switch parts.count {
        case 3: month(parts[1])
        case 2: String(parts[0])
        default: nil
        }
    }
}
