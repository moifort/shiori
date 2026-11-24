package com.polyforms.shiori.features.authors

import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.UpcomingRelease
import java.text.Normalizer
import java.time.LocalDate

/**
 * "Prochaines sorties" on the Authors shelf: what the authors the reader hearted have announced,
 * picked out of everything announced across their follows. A saga's volume names its author only
 * by name, so the hearted authors' names are matched too, not just the author an announcement
 * carries.
 */
object FavoriteAuthorReleases {
    /**
     * The releases still ahead whose author the reader hearted, in the server's order: the soonest
     * first, the undated last. A recording found for a narrator stays out: it belongs to the
     * narrator's news.
     */
    fun of(releases: List<UpcomingRelease>, favorites: List<String>, today: LocalDate = LocalDate.now()): List<UpcomingRelease> {
        val hearted = favorites.map(::folded).toSet()
        val day = today.toString()
        val seen = mutableSetOf<String>()
        return releases.filter { release ->
            if (release.source == ReleaseSource.NARRATOR || isPast(release.date, day)) return@filter false
            val byFavorite = release.author?.favorite == true || release.authors.any { folded(it) in hearted }
            byFavorite && seen.add(release.id)
        }
    }

    /** A snapshot's releases still ahead today: one written days ago may hold a date gone by. */
    fun stillAhead(releases: List<UpcomingRelease>, today: LocalDate = LocalDate.now()): List<UpcomingRelease> {
        val day = today.toString()
        return releases.filter { !isPast(it.date, day) }
    }

    /**
     * A date announced before today: `YYYY-MM-DD`, `YYYY-MM` or `YYYY`, each compared at its own
     * precision, so this month or this year still counts as ahead.
     */
    fun isPast(date: String?, today: String): Boolean {
        if (date.isNullOrEmpty()) return false
        return date < today.take(date.length)
    }

    private fun folded(name: String): String =
        Normalizer.normalize(name.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").trim()
}
