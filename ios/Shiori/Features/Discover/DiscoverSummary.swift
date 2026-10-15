import SwiftUI

/// What the Books shelf of Découvrir sums up in one line each.
enum DiscoverCategory: Hashable {
    /// "Bientôt disponible": the editions the reader awaits.
    case soon
    /// "Prix littéraires": the latest winners of the genres read most.
    case awards
    /// "Coups de cœur de vos amis": what the friends hearted.
    case friends

    var title: LocalizedStringKey {
        switch self {
        case .soon: "Bientôt disponible"
        case .awards: "Prix littéraires"
        case .friends: "Coups de cœur"
        }
    }

    var systemImage: String {
        switch self {
        case .soon: "clock.fill"
        case .awards: "trophy.fill"
        case .friends: "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .soon: .orange
        case .awards: .yellow
        case .friends: .red
        }
    }
}

/// The line under a category's name, saying at a glance what it holds.
enum DiscoverSummaryLine {
    /// The day of the soonest edition announced; else how many are awaited.
    static func soon(_ editions: [AwaitedEdition]) -> String {
        if let date = editions.compactMap(\.announcedDate).min(by: { lhs, rhs in
            ReleaseDateText.lastDay(lhs) < ReleaseDateText.lastDay(rhs)
        }) {
            return String(localized: "Prochain : \(ReleaseDateText.short(date))")
        }
        return inflected("^[\(editions.count) livre attendu](inflect: true)")
    }

    /// The words agreed with their number: only an attributed string carries
    /// out the inflection its markdown asks for.
    private static func inflected(_ resource: String.LocalizationValue) -> String {
        String(AttributedString(localized: resource).characters)
    }

    /// The genres the winners are drawn from, the most read first.
    static func awards(_ sections: [AwardSection]) -> String {
        sections.map(\.genre.label).joined(separator: " · ")
    }

    /// The friends behind the hearts, the newest first, each named once:
    /// "Marie", "Marie et Paul", "Marie, Paul +2".
    static func friends(_ books: [LovedBook]) -> String {
        var names: [String] = []
        for lover in books.flatMap(\.lovers.friends) where !names.contains(lover.displayName) {
            names.append(lover.displayName)
        }
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return String(localized: "\(names[0]) et \(names[1])")
        default: return "\(names[0]), \(names[1]) +\(names.count - 2)"
        }
    }
}

extension CoverTile {
    /// A tile on a summary line of Découvrir: larger than a library row's
    /// cover, smaller than a shelf's, the strip summing the category up rather
    /// than laying it out. Wide enough for a prize and its year under it.
    static let summaryWidth: CGFloat = 74
}
