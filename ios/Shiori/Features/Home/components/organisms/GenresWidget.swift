import SwiftUI

/// The genres of every book the reader has finished, whatever the year.
struct GenresWidget: View {
    let genres: [Dashboard.GenreSlice]
    /// Opens the library on its default view: the genres are no longer a
    /// view of their own.
    var onTapped: (() -> Void)?

    var body: some View {
        WidgetCard(title: "Genres lus", action: onTapped) {
            if genres.isEmpty {
                WidgetEmptyMessage(text: "Terminez un livre pour voir vos genres.", placeholder: .segments)
            } else {
                SegmentedBar(segments: genres.enumerated().map { index, slice in
                    SegmentedBar.Segment(
                        id: slice.id,
                        label: slice.genre?.label ?? String(localized: "Autres"),
                        value: slice.count,
                        color: slice.genre == nil
                            ? DashboardPalette.others
                            : DashboardPalette.genres[index % DashboardPalette.genres.count]
                    )
                })
            }
        }
        .accessibilityIdentifier("home-genres")
    }
}

#Preview {
    GenresWidget(genres: [
        .init(genre: .fantasy, count: 7),
        .init(genre: .scienceFiction, count: 4),
        .init(genre: .adventure, count: 3),
        .init(genre: .crime, count: 2),
        .init(genre: nil, count: 2),
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
