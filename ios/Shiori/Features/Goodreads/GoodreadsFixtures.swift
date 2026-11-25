import Foundation

/// What the Goodreads pages draw in their previews: an export as a real one
/// reads, a few of each shelf and verdict.
extension GoodreadsPreview {
    /// The showcase's cover on disk (`scripts/showcase-covers.ts`), none in a release build.
    private static func cover(_ slug: String) -> URL? {
        #if DEBUG
        Showcase.cover(slug)
        #else
        nil
        #endif
    }

    static let preview = GoodreadsPreview(
        rows: [
            GoodreadsRow(
                key: "red-rising", title: "Red Rising", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 1, rating: 5, shelf: .read, verdict: .new,
                coverURL: cover("red-rising")
            ),
            GoodreadsRow(
                key: "golden-son", title: "Golden Son", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 2, rating: 4.5, shelf: .read, verdict: .new,
                coverURL: cover("golden-son")
            ),
            GoodreadsRow(
                key: "morning-star", title: "Morning Star", authors: ["Pierce Brown"],
                seriesName: "Red Rising", volume: 3, shelf: .currentlyReading, verdict: .new,
                coverURL: cover("morning-star")
            ),
            GoodreadsRow(
                key: "la-horde", title: "La Horde du Contrevent", authors: ["Alain Damasio"],
                shelf: .toRead, verdict: .new,
                coverURL: cover("horde-du-contrevent")
            ),
            GoodreadsRow(
                key: "fondation", title: "Fondation", authors: ["Isaac Asimov"],
                seriesName: "Fondation", volume: 1, shelf: .toRead, verdict: .new,
                coverURL: cover("fondation")
            ),
            GoodreadsRow(
                key: "trois-corps", title: "Le Problème à trois corps", authors: ["Liu Cixin"],
                rating: 2, shelf: .read, dropped: true, verdict: .new,
                coverURL: cover("trois-corps")
            ),
            GoodreadsRow(
                key: "sorceleur", title: "Le Sorceleur, tome 1 : Le Dernier Vœu", authors: ["Andrzej Sapkowski"],
                shelf: .read, verdict: .uncertain, heldBookId: "dernier-voeu", heldTitle: "Le Dernier Vœu",
                heldCoverURL: cover("sorceleur-01"), coverURL: cover("sorceleur-01")
            ),
            GoodreadsRow(
                key: "nom-du-vent", title: "Le Nom du vent", authors: ["Patrick Rothfuss"],
                rating: 4, shelf: .read, verdict: .held, heldBookId: "nom-du-vent", heldTitle: "Le Nom du vent",
                heldCoverURL: cover("nom-du-vent"), coverURL: cover("nom-du-vent")
            ),
            GoodreadsRow(
                key: "dune", title: "Dune", authors: ["Frank Herbert"],
                rating: 5, shelf: .read, verdict: .held, heldBookId: "dune", heldTitle: "Dune",
                heldCoverURL: cover("dune"), coverURL: cover("dune")
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
