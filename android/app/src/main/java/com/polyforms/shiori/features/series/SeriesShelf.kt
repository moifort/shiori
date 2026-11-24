package com.polyforms.shiori.features.series

import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.SagaDiscovery
import com.polyforms.shiori.features.discover.SagaReleases
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.shared.DiscoveredVolume
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
    data class Missing(val number: Int?, val title: String, val date: String?, val coverURL: String?) : NextVolume
}

/**
 * What a tap on the next volume opens: the reader's own volume, else the page of the volume they
 * lack, as the saga screen opens it; the saga only for a volume with no number to file it at.
 */
sealed interface UpNextTarget {
    data class Book(val book: com.polyforms.shiori.shared.Book) : UpNextTarget
    data class Volume(val volume: DiscoveryVolume) : UpNextTarget
    data class Series(val series: FollowedSeries) : UpNextTarget
}

fun FollowedSeries.target(of: NextVolume): UpNextTarget = when (of) {
    is NextVolume.Owned -> UpNextTarget.Book(of.book)
    is NextVolume.Missing -> of.number?.let { number ->
        UpNextTarget.Volume(
            DiscoveryVolume(
                SagaDiscovery(this, SagaReleases(watched = true, next = null)),
                DiscoveredVolume(number, of.title, of.date, null, of.coverURL),
            ),
        )
    } ?: UpNextTarget.Series(this)
}

data class SeriesRelease(val number: Int?, val title: String, val date: String, val coverURL: String?)

val FollowedSeries.nextVolume: NextVolume?
    get() {
        val owned = strip.mapNotNull { (it as? SeriesStripItem.Owned)?.book }
        (owned.firstOrNull { it.status == ReadingStatus.READING } ?: owned.firstOrNull { it.status == ReadingStatus.TO_READ })?.let { return NextVolume.Owned(it) }
        val missing = strip.firstOrNull { it is SeriesStripItem.Missing && !it.forthcoming } as SeriesStripItem.Missing?
        return missing?.let { NextVolume.Missing(it.number, it.title, it.date, it.coverURL) }
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

/**
 * "Séries à continuer": the sagas being read, the next volume of each. A saga with a volume open
 * is left out: that volume is already in "À finir".
 */
val List<FollowedSeries>.upNext: List<Pair<FollowedSeries, NextVolume>>
    get() = filter { it.state == SeriesState.IN_PROGRESS }
        .mapNotNull { saga -> saga.nextVolume?.let { saga to it } }
        .filter { (_, volume) -> (volume as? NextVolume.Owned)?.book?.status != ReadingStatus.READING }

fun ShelvesView.keeps(entry: Pair<FollowedSeries, NextVolume>): Boolean {
    val (series, volume) = entry
    val format = (volume as? NextVolume.Owned)?.book?.format ?: if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
    val genre: BookGenre? = (volume as? NextVolume.Owned)?.book?.genre ?: series.genre
    return (this.format == null || format == this.format) && (this.genre == null || genre == this.genre)
}

/**
 * The status menu over a friend's sagas, in the corner as the one over "Livres": where the friend
 * stands on each saga, read off their own volumes.
 */
enum class SeriesStatusFilter {
    ALL, IN_PROGRESS, NOT_STARTED, COMPLETE, DROPPED, LOVED;

    val label: String
        get() = when (this) {
            ALL -> L("Toutes")
            IN_PROGRESS -> L("En cours")
            NOT_STARTED -> L("À commencer")
            COMPLETE -> L("Terminées")
            DROPPED -> L("Abandonnées")
            LOVED -> L("Préférées")
        }

    val symbol: String
        get() = when (this) {
            ALL -> "tray.full"
            IN_PROGRESS -> ReadingStatus.READING.symbol
            NOT_STARTED -> ReadingStatus.TO_READ.symbol
            COMPLETE -> ReadingStatus.READ.symbol
            DROPPED -> ReadingStatus.DROPPED.symbol
            LOVED -> "heart"
        }

    /** Whether the filter keeps the saga. Given up on: a volume dropped and none being read; such a saga is no longer "En cours". */
    fun keeps(series: FollowedSeries): Boolean {
        val statuses = series.volumes.map { it.status }
        val dropped = ReadingStatus.DROPPED in statuses && ReadingStatus.READING !in statuses
        return when (this) {
            ALL -> true
            IN_PROGRESS -> series.state == SeriesState.IN_PROGRESS && !dropped
            NOT_STARTED -> series.state == SeriesState.NOT_STARTED
            COMPLETE -> series.state == SeriesState.COMPLETE
            DROPPED -> dropped
            LOVED -> series.opinion?.favorite == true || (series.opinion?.rating ?: 0.0) >= 4
        }
    }
}

/** What the saga is held as, for the format pills: its first volume's. */
val FollowedSeries.heldFormat: BookFormat
    get() = volumes.firstOrNull()?.format ?: if (isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK

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
