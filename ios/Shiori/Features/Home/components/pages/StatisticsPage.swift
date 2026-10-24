import SwiftUI

/// The library's figures in full, behind the line of figures under the home
/// screen's hero: the counts as tiles, the genres read, the books, pages or
/// hours charted, and the book finished last. Each card opens the list it
/// counts. Stateless, as the home page.
struct StatisticsPage: View {
    let dashboard: Dashboard
    let onAction: (HomeAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatTilesRow(
                    readCount: dashboard.readCount,
                    favoriteCount: dashboard.favoriteCount,
                    toReadCount: dashboard.toReadCount,
                    onReadTapped: { onAction(.showLibrary(LibraryRequest(filter: .status(.read)))) },
                    onFavoritesTapped: { onAction(.showLibrary(LibraryRequest(filter: .favorites))) },
                    onPileTapped: { onAction(.showLibrary(LibraryRequest(filter: .status(.toRead)))) }
                )
                GenresWidget(genres: dashboard.genres) { onAction(.openGenres) }
                    .accessibilityIdentifier("home-genres")
                ReadingChartWidget(
                    currentYear: dashboard.currentYear,
                    booksPerYear: dashboard.booksPerYear,
                    pagesPerMonth: dashboard.pagesPerMonth,
                    hoursPerMonth: dashboard.hoursPerMonth,
                    hasAudiobooks: dashboard.hasAudiobooks,
                    hasPrintedBooks: dashboard.hasPrintedBooks
                )
                LastFinishedCard(book: dashboard.lastFinished) { onAction(.openBook($0)) }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StatisticsPage(dashboard: .preview) { _ in }
    }
}
