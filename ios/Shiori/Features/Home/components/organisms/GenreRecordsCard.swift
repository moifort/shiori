import SwiftUI

/// The genre that stands out on each of three counts: the longest books, the
/// fastest read, the most often given up. A record nobody holds is left out.
struct GenreRecordsCard: View {
    let longest: GenreInsights.LongestRecord?
    let fastest: GenreInsights.FastestRecord?
    let mostDropped: GenreInsights.DroppedRecord?

    var body: some View {
        WidgetCard(title: "Records par genre") {
            VStack(alignment: .leading, spacing: 14) {
                if let longest {
                    row(
                        symbol: "books.vertical",
                        tint: .indigo,
                        title: "Le pavé",
                        genre: longest.genre,
                        detail: String(localized: "\(longest.averagePages) pages en moyenne")
                    )
                }
                if let fastest {
                    row(
                        symbol: "hare",
                        tint: .green,
                        title: "Le plus dévoré",
                        genre: fastest.genre,
                        detail: String(localized: "\(fastest.averageDays) jours par livre")
                    )
                }
                if let mostDropped {
                    row(
                        symbol: "hand.thumbsdown",
                        tint: .red,
                        title: "Le plus abandonné",
                        genre: mostDropped.genre,
                        detail: String(localized: "\(mostDropped.droppedCount) sur \(mostDropped.startedCount) commencés")
                    )
                }
            }
        }
    }

    private func row(
        symbol: String,
        tint: Color,
        title: LocalizedStringKey,
        genre: BookGenre,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(genre.label) · \(detail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            genre.image
                .font(.subheadline)
                .foregroundStyle(genre.tint)
        }
    }
}

#Preview {
    GenreRecordsCard(
        longest: GenreInsights.preview.longest,
        fastest: GenreInsights.preview.fastest,
        mostDropped: GenreInsights.preview.mostDropped
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
