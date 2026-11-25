package com.polyforms.shiori.features.goodreads

import java.time.Instant

/** The Goodreads pages drawn in previews and from `--es preview goodreads`. */
object GoodreadsFixtures {
    val preview = GoodreadsPreview(
        rows = listOf(
            GoodreadsRow("red-rising", "Red Rising", listOf("Pierce Brown"), seriesName = "Red Rising", volume = 1, rating = 5.0, shelf = GoodreadsShelf.READ, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("golden-son", "Golden Son", listOf("Pierce Brown"), seriesName = "Red Rising", volume = 2, rating = 4.5, shelf = GoodreadsShelf.READ, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("morning-star", "Morning Star", listOf("Pierce Brown"), seriesName = "Red Rising", volume = 3, shelf = GoodreadsShelf.CURRENTLY_READING, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("la-horde", "La Horde du Contrevent", listOf("Alain Damasio"), shelf = GoodreadsShelf.TO_READ, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("fondation", "Fondation", listOf("Isaac Asimov"), seriesName = "Fondation", volume = 1, shelf = GoodreadsShelf.TO_READ, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("trois-corps", "Le Problème à trois corps", listOf("Liu Cixin"), rating = 2.0, shelf = GoodreadsShelf.READ, dropped = true, verdict = GoodreadsVerdict.NEW),
            GoodreadsRow("sorceleur", "Le Sorceleur, tome 1 : Le Dernier Vœu", listOf("Andrzej Sapkowski"), shelf = GoodreadsShelf.READ, verdict = GoodreadsVerdict.UNCERTAIN, heldBookId = "dernier-voeu", heldTitle = "Le Dernier Vœu"),
            GoodreadsRow("nom-du-vent", "Le Nom du vent", listOf("Patrick Rothfuss"), rating = 4.0, shelf = GoodreadsShelf.READ, verdict = GoodreadsVerdict.HELD, heldBookId = "nom-du-vent", heldTitle = "Le Nom du vent"),
            GoodreadsRow("dune", "Dune", listOf("Frank Herbert"), rating = 5.0, shelf = GoodreadsShelf.READ, verdict = GoodreadsVerdict.HELD, heldBookId = "dune", heldTitle = "Dune"),
        ),
        readCount = 812,
        readingCount = 3,
        toReadCount = 395,
        droppedCount = 12,
        ratedCount = 612,
        datedCount = 790,
        reviewedCount = 48,
    )

    val summary = GoodreadsImportSummary(Instant.ofEpochSecond(1_795_600_000), 1424, 214, 395, 0, 23)

    val outcome = GoodreadsImportOutcome(1029, 214, 395, 0)
}
