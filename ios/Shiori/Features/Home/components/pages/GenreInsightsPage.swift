import SwiftUI

/// What the reader's genres say about them, opened from the dashboard's genre
/// card. Stateless: it draws the figures it is handed. A card with too little
/// behind it to mean anything is left out rather than drawn from one point.
struct GenreInsightsPage: View {
    let insights: GenreInsights

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GenreRadar(shares: insights.shares)

                GenreSignatureCard(readCount: insights.readCount, shares: insights.shares)

                if !insights.formats.isEmpty {
                    FormatsCard(formats: insights.formats)
                }

                if insights.tastes.count >= 3, let averageRating = insights.averageRating {
                    TasteMap(
                        tastes: insights.tastes,
                        averageRating: averageRating,
                        gem: insights.gem
                    )
                }

                if insights.longest != nil || insights.fastest != nil || insights.mostDropped != nil {
                    GenreRecordsCard(
                        longest: insights.longest,
                        fastest: insights.fastest,
                        mostDropped: insights.mostDropped
                    )
                }

                if !insights.unexplored.isEmpty {
                    UnexploredGenresCard(unexplored: insights.unexplored)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Genres lus")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Bibliothèque") {
    NavigationStack {
        GenreInsightsPage(insights: .preview)
    }
}

#Preview("Premier livre") {
    NavigationStack {
        GenreInsightsPage(insights: .firstBook)
    }
}
