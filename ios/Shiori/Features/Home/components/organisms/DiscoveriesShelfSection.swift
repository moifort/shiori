import SwiftUI

/// The month's discoveries on the home page, drawn as Découvrir draws them:
/// the first two with why, then the bare covers of the others, which run off
/// the card's edge as the other shelves do. The heading opens Découvrir.
struct DiscoveriesShelfSection: View {
    let discoveries: MonthlyDiscoveries
    let onHeaderTapped: () -> Void
    let onOpen: (Suggestion) -> Void

    /// What the headphones overhang a tile's cover by: a third of the badge.
    private static let badgeRoom = (CoverTile.formatBadgeSize / 3).rounded(.up)

    var body: some View {
        let first = discoveries.suggestions.prefix(DiscoverySuggestionRows.count)
        let rest = discoveries.suggestions.dropFirst(DiscoverySuggestionRows.count)
        WidgetCard(title: "\(discoveries.title)", action: onHeaderTapped) {
            DiscoverySuggestionRows(suggestions: Array(first), isClosed: !rest.isEmpty, onOpen: onOpen)
            if !rest.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(rest) { suggestion in
                            Button { onOpen(suggestion) } label: {
                                CoverTile(book: suggestion.cover, caption: "")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("discover-suggestion")
                        }
                    }
                    .padding(.horizontal, 16)
                    // Room for the headphones, which overhang a recording's
                    // corner and the scroll view would otherwise clip; taken
                    // back outside so the covers stay where they were.
                    .padding(.top, Self.badgeRoom)
                }
                .padding(.horizontal, -16)
                .padding(.top, -Self.badgeRoom)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            DiscoveriesShelfSection(discoveries: .preview, onHeaderTapped: {}, onOpen: { _ in })
            DiscoveriesShelfSection(
                discoveries: MonthlyDiscoveries(
                    month: "2026-10",
                    suggestions: Array(MonthlyDiscoveries.preview.suggestions.prefix(2))
                ),
                onHeaderTapped: {},
                onOpen: { _ in }
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
