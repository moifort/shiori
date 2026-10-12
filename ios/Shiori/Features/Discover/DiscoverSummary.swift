import SwiftUI

/// What the Books shelf of Découvrir sums up in one line each, and opens as a
/// page of its own.
enum DiscoverCategory: Hashable {
    /// "Nouveautés": the volumes of the sagas followed, just out then announced.
    case news
    /// "Bientôt disponible": the editions the reader awaits.
    case soon
    /// "Prix littéraires": the latest winners of the genres read most.
    case awards
    /// "Coups de cœur de vos amis": what the friends hearted.
    case friends

    var title: LocalizedStringKey {
        switch self {
        case .news: "Nouveautés"
        case .soon: "Bientôt disponible"
        case .awards: "Prix littéraires"
        case .friends: "Coups de cœur de vos amis"
        }
    }

    /// Its name on its summary line, short enough to stand beside the covers.
    var shortTitle: LocalizedStringKey {
        switch self {
        case .friends: "Coups de cœur"
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .news: "sparkles"
        case .soon: "clock"
        case .awards: "trophy"
        case .friends: "heart"
        }
    }

    var tint: Color {
        switch self {
        case .news: .green
        case .soon: .orange
        case .awards: .yellow
        case .friends: .red
        }
    }
}

/// The line under a category's name, saying at a glance what it holds.
enum DiscoverSummaryLine {
    /// "2 sortis · 3 annoncés", either part left out when there is none.
    static func news(_ volumes: [DiscoveryVolume]) -> String {
        let coming = volumes.filter(\.isComing).count
        let out = volumes.count - coming
        var parts: [String] = []
        if out > 0 { parts.append(inflected("^[\(out) sorti](inflect: true)")) }
        if coming > 0 { parts.append(inflected("^[\(coming) annoncé](inflect: true)")) }
        return parts.joined(separator: " · ")
    }

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

/// One category of the Books shelf in a line: its symbol, its name, what it
/// holds in a few words, and the first covers fanned out on the trailing edge.
struct DiscoverSummaryRow: View {
    let category: DiscoverCategory
    let line: String
    let covers: [Book]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(category.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.shortTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(verbatim: line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            CoverFan(books: Array(covers.prefix(3)))
        }
        .padding(.vertical, 4)
    }
}

/// A few covers overlapping, the first on top, as a hand of cards spread on a
/// table: each edged in the row's background so it stands apart from the one
/// under it.
struct CoverFan: View {
    let books: [Book]

    private let width: CGFloat = 32

    var body: some View {
        HStack(spacing: -width * 0.55) {
            ForEach(Array(books.enumerated()), id: \.offset) { index, book in
                BookCover(book: book, width: width, showsFormatBadge: false)
                    .padding(1.5)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: .rect(cornerRadius: width * 0.07 + 1.5)
                    )
                    .rotationEffect(.degrees(Double(index) * 5 - 5), anchor: .bottom)
                    .zIndex(Double(books.count - index))
            }
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }
}

#Preview {
    List {
        Section {
            DiscoverSummaryRow(
                category: .news,
                line: "2 sortis · 1 annoncé",
                covers: [AwaitedEdition.preview.cover, AwaitedEdition.preview.cover]
            )
            DiscoverSummaryRow(
                category: .soon,
                line: DiscoverSummaryLine.soon([.preview]),
                covers: [AwaitedEdition.preview.cover]
            )
            DiscoverSummaryRow(category: .awards, line: "Science-fiction · Fantastique", covers: [])
            DiscoverSummaryRow(category: .friends, line: "Marie, Paul +2", covers: [])
        }
    }
}
