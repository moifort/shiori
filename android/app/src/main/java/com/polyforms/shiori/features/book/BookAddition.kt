package com.polyforms.shiori.features.book

import com.polyforms.shiori.features.scan.ScanApi
import com.polyforms.shiori.features.scan.ScannedBook
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.BookOrigin
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.track

/**
 * Adding a book from what little a catalogue knows: the title is looked up first, and what the
 * lookup recognised completes the draft, the reader's own choices kept.
 */
object BookAddition {
    sealed interface LookUp {
        data class Title(val title: String) : LookUp
        data class Volume(
            val title: String,
            val author: String,
            val membership: SeriesMembership,
            val format: BookFormat,
            val media: List<BookMedium>,
            val language: BookLanguage?,
        ) : LookUp
    }

    suspend fun add(draft: BookDraft, lookUp: LookUp? = null, source: AnalyticsEvent.BookSource): Book {
        var completed = draft
        if (lookUp != null) {
            val found = runCatching { find(lookUp) }.getOrNull()
            if (found != null && found.recognized) completed = draft.completedBy(found.asDraft)
        }
        // The caller may know better than the screen: a wish keeps where it was come across, an
        // awaited edition says it was awaited.
        if (completed.origin == null) completed = completed.copy(origin = BookOrigin(source.origin))
        val added = BookApi.add(completed)
        track(AnalyticsEvent.BookAdded(source))
        return added
    }

    private suspend fun find(lookUp: LookUp): ScannedBook = when (lookUp) {
        is LookUp.Title -> ScanApi.lookUpTitle(lookUp.title)
        is LookUp.Volume -> ScanApi.lookUpVolume(lookUp.title, lookUp.author, lookUp.membership, lookUp.format, lookUp.media, lookUp.language)
    }
}

/** The origin a book added from here is recorded with. */
val AnalyticsEvent.BookSource.origin: BookOrigin.Kind
    get() = when (this) {
        AnalyticsEvent.BookSource.SCAN -> BookOrigin.Kind.SCAN
        AnalyticsEvent.BookSource.MANUAL -> BookOrigin.Kind.MANUAL
        AnalyticsEvent.BookSource.SERIES -> BookOrigin.Kind.SERIES
        AnalyticsEvent.BookSource.DISCOVER -> BookOrigin.Kind.DISCOVER
        AnalyticsEvent.BookSource.AUTHOR -> BookOrigin.Kind.AUTHOR
        AnalyticsEvent.BookSource.SHELF -> BookOrigin.Kind.SHELF
    }
