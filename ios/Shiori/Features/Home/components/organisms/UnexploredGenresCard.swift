import SwiftUI

/// The genres the reader has never finished a book of. Those with a book
/// already waiting on the pile come first, in their colour, with the count.
struct UnexploredGenresCard: View {
    let unexplored: [GenreInsights.Unexplored]

    /// "Other" is not a territory: the list counts every genre but that one.
    private var genreCount: Int { BookGenre.allCases.count - 1 }

    var body: some View {
        WidgetCard(title: "Terres inexplorées") {
            Text("\(unexplored.count) sur \(genreCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } content: {
            PillFlow {
                ForEach(unexplored) { item in
                    if item.pileCount > 0 {
                        Pill(
                            text: String(localized: "\(item.genre.label) · \(item.pileCount) sur la pile"),
                            systemImage: "bookmark",
                            tint: item.genre.tint
                        )
                    } else {
                        Pill(text: item.genre.label)
                    }
                }
            }
        }
    }
}

#Preview {
    UnexploredGenresCard(unexplored: GenreInsights.preview.unexplored)
        .padding()
        .background(Color(.systemGroupedBackground))
}
