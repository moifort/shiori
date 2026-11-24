package com.polyforms.shiori.features.scan

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.VolumeKind

/** The scan review's previews: a first volume read off a cover, and the saga it opens. */
object ScanFixtures {
    val sagaDraft = BookDraft(
        title = "Hypérion",
        authors = listOf("Dan Simmons"),
        publisher = "Robert Laffont",
        firstPublishedIn = 1989,
        synopsis = "Sur la planète Hypérion, aux confins de l'Hégémonie, se dressent les Tombeaux du Temps, gardés par le Gritche, une créature de métal et de lames. À la veille d'une guerre, sept pèlerins partent les visiter.",
        genre = BookGenre.SCIENCE_FICTION,
        subgenres = listOf("Space opera"),
        pageCount = 576,
        isbn13 = "9782221248478",
        language = BookLanguage.FR,
        series = SeriesMembership("hyperion", "Les Cantos d'Hypérion", 1, VolumeKind.MAIN),
    )

    val sagaVolumes: List<SeriesStripItem> = listOf(
        SeriesStripItem.Missing("hyperion-1", 1, "Hypérion", forthcoming = false),
        SeriesStripItem.Missing("hyperion-2", 2, "La Chute d'Hypérion", forthcoming = false),
        SeriesStripItem.Missing("hyperion-3", 3, "Endymion", forthcoming = false),
        SeriesStripItem.Missing("hyperion-4", 4, "L'Éveil d'Endymion", forthcoming = false),
    )
}
