package com.polyforms.shiori.features.narrators

import com.polyforms.shiori.features.authors.FavoriteAuthorReleases
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.UpcomingRelease
import java.time.LocalDate

/**
 * "Prochaines sorties" on the Narrators shelf: the recordings announced for the narrators the reader
 * hearted. The server finds them only for the hearted narrators, off the narrator watches, so
 * nothing is matched here: the narrators' releases are kept, those gone by and the repeats left out.
 */
object FavoriteNarratorReleases {
    /** The narrators' releases still ahead, in the server's order: the soonest first, the undated last. */
    fun of(releases: List<UpcomingRelease>, today: LocalDate = LocalDate.now()): List<UpcomingRelease> {
        val seen = mutableSetOf<String>()
        val narrated = releases.filter { it.source == ReleaseSource.NARRATOR && seen.add(it.id) }
        return FavoriteAuthorReleases.stillAhead(narrated, today)
    }
}
