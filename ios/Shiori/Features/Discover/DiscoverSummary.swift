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

/// One category of the Books shelf: its symbol, its name and what it holds
/// in a few words over a strip of every cover it holds, a tap on one opening
/// its page. A friend's page draws its shelves the same way; a line with no
/// covers is the heading alone.
struct DiscoverSummaryRow<Covers: View>: View {
    let title: LocalizedStringKey
    /// Nil for a line whose name says enough on its own.
    let systemImage: String?
    let tint: Color
    let line: String
    private let hasCovers: Bool
    @ViewBuilder let covers: Covers

    init(category: DiscoverCategory, line: String, @ViewBuilder covers: () -> Covers) {
        self.init(
            title: category.title,
            systemImage: category.systemImage,
            tint: category.tint,
            line: line,
            covers: covers
        )
    }

    init(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        line: String,
        @ViewBuilder covers: () -> Covers
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.line = line
        hasCovers = true
        self.covers = covers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
                .padding(.horizontal, 12)
            // Cut as far from the card's right edge as the first cover stands
            // from its left one; the room left of that cover is for the badges
            // overhanging its corner.
            if hasCovers {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) { covers }
                        .padding(.leading, 6)
                        .padding(.top, 6)
                }
                .padding(.leading, 6)
                .padding(.trailing, 12)
            }
        }
        .padding(.vertical, 12)
        .listRowInsets(EdgeInsets())
        // The line between two categories runs from edge to edge of the card.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width }
    }

    /// The name and what the category holds, its symbol in its colour on the
    /// top trailing corner.
    private var heading: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(verbatim: line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension DiscoverSummaryRow where Covers == EmptyView {
    /// A line with nothing under its heading: a shelf too long to sum up in
    /// covers, opened whole by a tap.
    init(title: LocalizedStringKey, systemImage: String? = nil, tint: Color = .accentColor, line: String) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.line = line
        hasCovers = false
        covers = EmptyView()
    }
}

extension CoverTile {
    /// A tile on a summary line of Découvrir: larger than a library row's
    /// cover, smaller than a shelf's, the strip summing the category up rather
    /// than laying it out. Wide enough for a prize and its year under it.
    static let summaryWidth: CGFloat = 74
}

#Preview {
    List {
        Section {
            DiscoverSummaryRow(category: .soon, line: DiscoverSummaryLine.soon([.preview])) {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
            DiscoverSummaryRow(category: .friends, line: "Marie, Paul +2") {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
        }
    }
}
