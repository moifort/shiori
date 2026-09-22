import SwiftUI

/// The dashboard laid out top to bottom. Stateless: the coordinator hands it the
/// figures and receives the taps. Every widget is drawn from the first book on;
/// one with nothing to show yet says what will fill it.
struct HomePage: View {
    let dashboard: Dashboard
    /// The page is last session's snapshot and a fresher one is on its way: a
    /// spinner leads the page rather than a loader replacing it.
    var isRefreshing: Bool = false
    /// That refresh failed — the leading row becomes a retry.
    var refreshFailed: Bool = false
    var onRetryRefresh: () async -> Void = {}
    /// The "reading" shelf: opens the library on the books being read.
    let onReadingTapped: () -> Void
    /// The progress card: opens the Series tab on the sagas in progress.
    let onSeriesTapped: () -> Void
    /// The pile tile and the suggestions shelf, which is drawn from the pile:
    /// open the library on the books to read.
    var onPileTapped: () -> Void = {}
    /// The average rating tile: opens the library on the rated books, best first.
    let onRatingTapped: () -> Void
    var onReadTapped: () -> Void = {}
    var onFavoritesTapped: () -> Void = {}
    var onDroppedTapped: () -> Void = {}
    let onGenresTapped: () -> Void
    /// Opens the add sheet from the prompt that leads an empty library.
    var onScan: () -> Void = {}
    let onBookTapped: (Book) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isRefreshing || refreshFailed {
                    RefreshRow(
                        failed: refreshFailed,
                        loadingLabel: "Mise à jour de l'accueil",
                        onRetry: onRetryRefresh
                    )
                }

                // The one thing a reader can do from an empty dashboard, above
                // the cards it will fill.
                if dashboard.libraryIsEmpty {
                    scanPrompt
                }

                ReadingChartWidget(
                    currentYear: dashboard.currentYear,
                    booksPerYear: dashboard.booksPerYear,
                    pagesPerMonth: dashboard.pagesPerMonth,
                    hoursPerMonth: dashboard.hoursPerMonth,
                    hasAudiobooks: dashboard.hasAudiobooks,
                    hasPrintedBooks: dashboard.hasPrintedBooks
                )

                BookShelfSection(
                    title: "En cours",
                    books: dashboard.reading,
                    caption: Self.startedCaption,
                    emptyMessage: "Aucun livre en cours de lecture.",
                    onHeaderTapped: onReadingTapped,
                    onBookTapped: onBookTapped
                )
                .accessibilityIdentifier("home-reading")

                BookShelfSection(
                    title: "Vous aimerez peut-être lire",
                    books: dashboard.suggestions,
                    caption: { $0.authorLine },
                    emptyMessage: "Ajoutez des livres à votre pile à lire pour en tirer quelques idées.",
                    onHeaderTapped: onPileTapped,
                    onBookTapped: onBookTapped
                )
                .accessibilityIdentifier("home-suggestions")

                LastFinishedCard(book: dashboard.lastFinished, onTapped: onBookTapped)

                TrendsWidget(pagesPerDay: dashboard.pagesPerDay, daysToFinish: dashboard.daysToFinish)

                StatTilesRow(
                    toReadCount: dashboard.toReadCount,
                    monthsToClearPile: dashboard.monthsToClearPile,
                    averageRating: dashboard.averageRating,
                    ratedCount: dashboard.ratedCount,
                    readCount: dashboard.readCount,
                    favoriteCount: dashboard.favoriteCount,
                    droppedCount: dashboard.droppedCount,
                    onPileTapped: onPileTapped,
                    onRatingTapped: onRatingTapped,
                    onReadTapped: onReadTapped,
                    onFavoritesTapped: onFavoritesTapped,
                    onDroppedTapped: onDroppedTapped
                )

                GenresWidget(
                    genres: dashboard.genres,
                    onTapped: onGenresTapped
                )

                SeriesProgressWidget(series: dashboard.series, onHeaderTapped: onSeriesTapped)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var scanPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Votre bibliothèque est vide").font(.headline)
            } icon: {
                Image(systemName: "books.vertical").foregroundStyle(.tint)
            }
            Text("Scannez la couverture d'un livre pour commencer. Chaque carte ci-dessous se remplira avec vos lectures.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onScan) {
                Label("Scanner un livre", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("home-scan")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    /// A recording says how far the player got; a book says how long it has
    /// been open, since nobody tracks its pages.
    private static func startedCaption(_ book: Book) -> String {
        if let progress = book.listeningProgressLabel {
            return String(localized: "\(progress) écouté")
        }
        guard let startedAt = book.startedAt else { return book.authorLine }
        let days = startedAt.daysAgo()
        return days == 0
            ? String(localized: "commencé aujourd'hui")
            : String(localized: "depuis \(days) j")
    }
}

extension Dashboard {
    static let preview = Dashboard(
        currentYear: 2026,
        booksPerYear: [
            .init(year: 2022, count: 9), .init(year: 2023, count: 14), .init(year: 2024, count: 21),
            .init(year: 2025, count: 16), .init(year: 2026, count: 18),
        ],
        pagesPerMonth: [410, 720, 380, 910, 760, 600, 1180, 1100, 260, 0, 0, 0].enumerated()
            .map { .init(month: $0.offset + 1, pages: $0.element) },
        hoursPerMonth: [6, 11, 4, 0, 9, 14, 7, 12, 3, 0, 0, 0].enumerated()
            .map { .init(month: $0.offset + 1, hours: $0.element) },
        reading: [
            Book(id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"], status: .reading,
                 startedAt: .now.addingTimeInterval(-12 * 86400)),
            Book(id: "2", title: "One Piece", authors: ["Eiichirō Oda"], status: .reading,
                 startedAt: .now.addingTimeInterval(-2 * 86400)),
            Book(id: "3", title: "Dune", authors: ["Frank Herbert"], status: .reading,
                 startedAt: .now.addingTimeInterval(-41 * 86400)),
            Book(id: "4", title: "Blacksad", authors: ["Juan Díaz Canales"], status: .reading,
                 startedAt: .now.addingTimeInterval(-5 * 86400)),
        ],
        suggestions: [
            Book(id: "5", title: "Hypérion", authors: ["Dan Simmons"], status: .toRead),
            Book(id: "6", title: "Les Furtifs", authors: ["Alain Damasio"], status: .toRead),
            Book(id: "7", title: "Vagabond", authors: ["Takehiko Inoue"], status: .toRead),
            Book(id: "8", title: "Le Problème à trois corps", authors: ["Liu Cixin"], status: .toRead),
        ],
        lastFinished: Book(
            id: "9", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read, rating: 5,
            startedAt: .now.addingTimeInterval(-13 * 86400), finishedAt: .now.addingTimeInterval(-4 * 86400)
        ),
        pagesPerDay: .init(current: 24, previous: 18),
        daysToFinish: .init(current: 11, previous: 14),
        toReadCount: 27,
        readCount: 142,
        monthsToClearPile: 9,
        averageRating: 4.2,
        ratedCount: 18,
        genres: [
            .init(genre: .fantasy, count: 7), .init(genre: .scienceFiction, count: 4),
            .init(genre: .adventure, count: 3), .init(genre: .crime, count: 2), .init(genre: nil, count: 2),
        ],
        series: [
            .init(id: "a", name: "One Piece", readCount: 107, totalCount: 110, favorite: true),
            .init(id: "b", name: "Chronique du tueur de roi", readCount: 1, totalCount: 2, rating: 4),
        ],
        favoriteCount: 6,
        droppedCount: 2,
        hasAudiobooks: true,
        libraryIsEmpty: false
    )
}

extension Dashboard {
    /// A library with one book just added: every widget drawn, most of them
    /// saying what will fill them.
    static let firstBook = Dashboard(
        currentYear: 2026,
        booksPerYear: (2018...2026).map { .init(year: $0, count: 0) },
        pagesPerMonth: (1...12).map { .init(month: $0, pages: 0) },
        hoursPerMonth: (1...12).map { .init(month: $0, hours: 0) },
        reading: [],
        suggestions: [Book(id: "1", title: "Dune", authors: ["Frank Herbert"], status: .toRead)],
        lastFinished: nil,
        pagesPerDay: .init(current: nil, previous: nil),
        daysToFinish: .init(current: nil, previous: nil),
        toReadCount: 1,
        monthsToClearPile: nil,
        averageRating: nil,
        ratedCount: 0,
        genres: [],
        series: [],
        libraryIsEmpty: false
    )
}

#Preview("With data") {
    NavigationStack {
        HomePage(dashboard: .preview, onReadingTapped: {}, onSeriesTapped: {}, onRatingTapped: {}, onGenresTapped: {}, onBookTapped: { _ in })
            .navigationTitle("Accueil")
    }
}

#Preview("First book") {
    NavigationStack {
        HomePage(dashboard: .firstBook, onReadingTapped: {}, onSeriesTapped: {}, onRatingTapped: {}, onGenresTapped: {}, onBookTapped: { _ in })
            .navigationTitle("Accueil")
    }
}
