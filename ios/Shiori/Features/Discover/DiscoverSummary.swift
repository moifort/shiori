import SwiftUI

/// What the Books shelf of Découvrir sums up in one line each, and opens as a
/// page of its own.
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
        case .soon: "clock"
        case .awards: "trophy"
        case .friends: "heart"
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
/// in a few words over a strip of its covers. The heading opens the category's
/// page; a cover opens its own, as the category's page would.
struct DiscoverSummaryRow<Covers: View>: View {
    let category: DiscoverCategory
    let line: String
    let onOpen: () -> Void
    @ViewBuilder let covers: Covers

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) { heading }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) { covers }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 12)
        .listRowInsets(EdgeInsets())
    }

    private var heading: some View {
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
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

extension CoverTile {
    /// A tile on a summary line of Découvrir: larger than a library row's
    /// cover, smaller than a shelf's, the strip summing the category up rather
    /// than laying it out.
    static let summaryWidth: CGFloat = 64
}

#Preview {
    List {
        Section {
            DiscoverSummaryRow(category: .soon, line: DiscoverSummaryLine.soon([.preview]), onOpen: {}) {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
            DiscoverSummaryRow(category: .friends, line: "Marie, Paul +2", onOpen: {}) {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
        }
    }
}
