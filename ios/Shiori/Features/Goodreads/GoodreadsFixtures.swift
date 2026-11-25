import Foundation

/// What the Goodreads pages draw in their previews: an export as a real one
/// reads, a few of each shelf and verdict.
extension GoodreadsPreview {
    static let preview = GoodreadsPreview(
        rows: [
            GoodreadsRow(
                key: "red-rising", title: "Red Rising", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 1, rating: 5, shelf: .read, verdict: .new
            ),
            GoodreadsRow(
                key: "golden-son", title: "Golden Son", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 2, rating: 4.5, shelf: .read, verdict: .new
            ),
            GoodreadsRow(
                key: "morning-star", title: "Morning Star", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 3, shelf: .currentlyReading, verdict: .new
            ),
            GoodreadsRow(
                key: "la-horde", title: "La Horde du Contrevent", authors: ["Alain Damasio"],
                shelf: .toRead, verdict: .new
            ),
            GoodreadsRow(
                key: "fondation", title: "Fondation", authors: ["Isaac Asimov"],
                seriesName: "Fondation", volume: 1, shelf: .toRead, verdict: .new
            ),
            GoodreadsRow(
                key: "trois-corps", title: "Le Problème à trois corps", authors: ["Liu Cixin"],
                rating: 2, shelf: .read, dropped: true, verdict: .new
            ),
            GoodreadsRow(
                key: "sorceleur", title: "Le Sorceleur, tome 1 : Le Dernier Vœu", authors: ["Andrzej Sapkowski"],
                shelf: .read, verdict: .uncertain, heldBookId: "dernier-voeu", heldTitle: "Le Dernier Vœu"
            ),
            GoodreadsRow(
                key: "nom-du-vent", title: "Le Nom du vent", authors: ["Patrick Rothfuss"],
                rating: 4, shelf: .read, verdict: .held, heldBookId: "nom-du-vent", heldTitle: "Le Nom du vent"
            ),
            GoodreadsRow(
                key: "dune", title: "Dune", authors: ["Frank Herbert"],
                rating: 5, shelf: .read, verdict: .held, heldBookId: "dune", heldTitle: "Dune"
            ),
        ],
        readCount: 812,
        readingCount: 3,
        toReadCount: 395,
        droppedCount: 12,
        ratedCount: 612,
        datedCount: 790,
        reviewedCount: 48
    )
}

extension GoodreadsImportSummary {
    static let preview = GoodreadsImportSummary(
        importedAt: Date(timeIntervalSince1970: 1_795_600_000),
        imported: 1424,
        completed: 214,
        wished: 395,
        pendingCovers: 0,
        withoutCover: 23
    )
}

extension GoodreadsImportOutcome {
    static let preview = GoodreadsImportOutcome(imported: 1029, completed: 214, wished: 395, pendingCovers: 0)
}
