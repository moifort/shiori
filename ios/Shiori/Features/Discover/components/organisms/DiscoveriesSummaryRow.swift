import SwiftUI

/// Découvrir's line of the month's discoveries: every cover of the month's
/// selection, bare, as the other lines — or, while the selection is being
/// made, five covers still blank under "Recherche de vos découvertes…", and
/// once it ran out, the heading alone saying when the next ones come.
struct DiscoveriesSummaryRow: View {
    let line: DiscoveriesLine
    let width: CGFloat
    let onOpen: (Suggestion) -> Void

    var body: some View {
        switch line {
        case .shown(let discoveries):
            DiscoverSummaryRow(
                title: "\(discoveries.title)",
                systemImage: "sparkles",
                tint: .purple,
                line: String(localized: "D’après vos préférences")
            ) {
                ForEach(discoveries.suggestions) { suggestion in
                    Button { onOpen(suggestion) } label: {
                        CoverTile(book: suggestion.cover, caption: "", width: width)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-suggestion")
                }
            }
            .accessibilityIdentifier("discover-discoveries")
        case .searching(let month):
            DiscoverSummaryRow(
                title: "\(MonthlyDiscoveries.title(month: month))",
                systemImage: "sparkles",
                tint: .purple,
                line: String(localized: "Recherche de vos découvertes…")
            ) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: width, height: width * 1.5)
                }
                .phaseAnimator([0.45, 1]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.9) }
            }
            .accessibilityIdentifier("discover-discoveries-searching")
        case .ranOut(let discoveries):
            // The heading alone: a month that ran out takes no more room than
            // it needs.
            DiscoverSummaryRow(
                title: "\(discoveries.title)",
                systemImage: "sparkles",
                tint: .purple,
                line: discoveries.nextLine
            )
            .accessibilityIdentifier("discover-discoveries-ran-out")
        }
    }
}

#Preview {
    List {
        DiscoveriesSummaryRow(line: .shown(.preview), width: CoverTile.summaryWidth) { _ in }
        DiscoveriesSummaryRow(line: .searching(month: "2026-10"), width: CoverTile.summaryWidth) { _ in }
        DiscoveriesSummaryRow(line: .ranOut(MonthlyDiscoveries(month: "2026-10", suggestions: [])), width: CoverTile.summaryWidth) { _ in }
    }
}
