package com.polyforms.shiori.features.series

import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.features.library.ShelvesView
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.SeriesStripItem

/** The volumes of a saga the reader is measured on: owned or out, never announced. */
val FollowedSeries.totalCount: Int
    get() = maxOf(strip.count { it !is SeriesStripItem.Missing || !it.forthcoming }, ownedCount)

val FollowedSeries.readCount: Int
    get() = strip.mapNotNull { (it as? SeriesStripItem.Owned)?.book?.takeIf { b -> b.status == ReadingStatus.READ } }
        .map { it.series?.volume?.toString() ?: it.id }.toSet().size

val FollowedSeries.missingCount: Int get() = strip.count { it is SeriesStripItem.Missing && !it.forthcoming }

/** What the reader has next in a saga: a volume they hold, or one out they lack. */
sealed interface NextVolume {
    data class Owned(val book: Book) : NextVolume
    data class Missing(val number: Int?, val title: String, val coverURL: String?) : NextVolume
}

data class SeriesRelease(val number: Int?, val title: String, val date: String, val coverURL: String?)

val FollowedSeries.nextVolume: NextVolume?
    get() {
        val owned = strip.mapNotNull { (it as? SeriesStripItem.Owned)?.book }
        (owned.firstOrNull { it.status == ReadingStatus.READING } ?: owned.firstOrNull { it.status == ReadingStatus.TO_READ })?.let { return NextVolume.Owned(it) }
        val missing = strip.firstOrNull { it is SeriesStripItem.Missing && !it.forthcoming } as SeriesStripItem.Missing?
        return missing?.let { NextVolume.Missing(it.number, it.title, it.coverURL) }
    }

val FollowedSeries.nextRelease: SeriesRelease?
    get() = strip.firstNotNullOfOrNull { item ->
        (item as? SeriesStripItem.Missing)?.takeIf { it.forthcoming && it.date != null }?.let { SeriesRelease(it.number, it.title, it.date!!, it.coverURL) }
    }

val FollowedSeries.progress: Dashboard.SeriesProgress
    get() = Dashboard.SeriesProgress(seriesId, name, isAudio, language, readCount, totalCount, opinion?.rating, opinion?.favorite == true, cardCoverURL)

val FollowedSeries.isSetAside: Boolean get() = state == SeriesState.UNFOLLOWED

/** "Tome 4 · 8 oct.": the next volume announced, as a tag under the saga's row. */
val FollowedSeries.releaseTag: String?
    get() {
        val announced = announced
        val date = announced?.date
        if (announced != null && date != null) return L("Tome %lld · %@", announced.number, ReleaseDateText.short(date))
        val release = nextRelease ?: return null
        val number = release.number ?: return ReleaseDateText.short(release.date)
        return L("Tome %lld · %@", number, ReleaseDateText.short(release.date))
    }

/** The sagas under way with their next volume, for "À suivre". */
val List<FollowedSeries>.upNext: List<Pair<FollowedSeries, NextVolume>>
    get() = filter { it.state == SeriesState.IN_PROGRESS }.mapNotNull { saga -> saga.nextVolume?.let { saga to it } }

fun ShelvesView.keeps(entry: Pair<FollowedSeries, NextVolume>): Boolean {
    val (series, volume) = entry
    val format = (volume as? NextVolume.Owned)?.book?.format ?: if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
    val genre: BookGenre? = (volume as? NextVolume.Owned)?.book?.genre ?: series.genre
    return (this.format == null || format == this.format) && (this.genre == null || genre == this.genre)
}

enum class SeriesShelfFilter {
    ALL, IN_PROGRESS, INCOMPLETE, LOVED, NOT_STARTED, COMPLETE, NOT_FOLLOWED;

    val label: String
        get() = when (this) {
            ALL -> L("Toutes")
            IN_PROGRESS -> L("En cours")
            INCOMPLETE -> L("À compléter")
            LOVED -> L("Préférées")
            NOT_STARTED -> L("À commencer")
            COMPLETE -> L("Terminées")
            NOT_FOLLOWED -> L("Non suivies")
        }

    fun keeps(series: FollowedSeries): Boolean {
        if (this == NOT_FOLLOWED) return series.isSetAside
        if (series.isSetAside) return false
        return when (this) {
            ALL -> true
            IN_PROGRESS -> series.state == SeriesState.IN_PROGRESS
            INCOMPLETE -> series.missingCount > 0
            LOVED -> series.opinion?.favorite == true || (series.opinion?.rating ?: 0.0) >= 4
            NOT_STARTED -> series.state == SeriesState.NOT_STARTED
            COMPLETE -> series.state == SeriesState.COMPLETE
            NOT_FOLLOWED -> true
        }
    }

    companion object {
        fun offered(series: List<FollowedSeries>): List<SeriesShelfFilter> = entries.filter { it == ALL || series.any(it::keeps) }
    }
}
