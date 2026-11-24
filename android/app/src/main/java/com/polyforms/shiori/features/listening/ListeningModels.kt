package com.polyforms.shiori.features.listening

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import kotlinx.serialization.Serializable
import java.time.Instant

/** A chapter of a recording, in playing order. */
@Serializable
data class ListeningChapter(
    val title: String,
    /** Seconds from the start of the recording. */
    val start: Double,
    val length: Double,
) {
    val end: Double get() = start + length
}

/**
 * What the player needs to play one Audible title, from a licence the server asked Amazon for.
 * The stream is Widevine-encrypted DASH that Android's own DRM plays as it is; its key is traded
 * through the server, which keeps the device credentials.
 */
data class Playback(
    val asin: String,
    /** Opaque, handed back with every saved position. */
    val contentReference: String,
    val streamURL: String,
    val duration: Double,
    val chapters: List<ListeningChapter>,
    /** Where the reader stopped last, on any of their Audible players. */
    val resumeAt: Double?,
    /** When that position was saved. */
    val resumeSavedAt: Instant? = null,
) {
    companion object
}

/**
 * The title being listened to, as the player draws it: what the list it was started from already
 * knew, so the accessory shows it before the licence is in.
 */
@Serializable
data class ListeningTitle(
    val asin: String,
    val title: String,
    /** The series and the volume, "Les Cantos d'Hypérion · Tome 3", or the author. */
    val subtitle: String?,
    val coverURL: String?,
    /** The book in the library, to open its page from the player. */
    val bookID: String? = null,
) {
    val id: String get() = asin

    companion object {
        /**
         * The title an audiobook of the library plays, or null when it has none: only a
         * recording imported from a linked Audible account can be played.
         */
        fun of(book: Book): ListeningTitle? {
            val asin = book.audibleAsin
            if (book.format != BookFormat.AUDIOBOOK || asin == null) return null
            val series = book.series?.let { membership ->
                membership.volume?.let { "${membership.name} · ${L("Tome %lld", it)}" } ?: membership.name
            }
            return ListeningTitle(asin, book.title, series ?: book.authors.firstOrNull(), book.coverURL, book.id)
        }
    }
}

/**
 * One audiobook of the player's queue: what follows once the title playing ends, and how far
 * into it the reader already is.
 */
data class ListeningQueueEntry(
    val title: ListeningTitle,
    /** Whole percent heard, on a recording under way; null on the pile. */
    val heard: Int?,
) {
    val id: String get() = title.asin

    companion object {
        fun of(book: Book): ListeningQueueEntry? = ListeningTitle.of(book)?.let {
            ListeningQueueEntry(it, if (book.status == ReadingStatus.READING) book.listeningProgress else null)
        }
    }
}
