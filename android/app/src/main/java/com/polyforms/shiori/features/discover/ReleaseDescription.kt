package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.scan.ScannedBook
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat

/** What the web says of a book to come: its record, and for a recording who reads it and how long. */
data class ReleaseDescription(val book: ScannedBook, val narrators: List<String>, val durationMinutes: Int?)

/** The book filled in from its description, its own fields kept where it has them. */
fun Book.described(description: ReleaseDescription?): Book {
    val base = if (format == BookFormat.AUDIOBOOK) copy(media = emptyList()) else this
    val found = description?.book ?: return base
    return base.copy(
        publisher = publisher ?: found.publisher,
        firstPublishedIn = firstPublishedIn ?: found.firstPublishedIn,
        synopsis = synopsis ?: found.synopsis,
        genre = genre ?: found.genre,
        subgenres = subgenres.ifEmpty { found.subgenres },
        pageCount = if (format != BookFormat.AUDIOBOOK) pageCount ?: found.pageCount else pageCount,
        isbn13 = if (format != BookFormat.AUDIOBOOK) isbn13 ?: found.isbn13 else isbn13,
        language = language ?: found.language,
        coverURL = coverURL ?: found.coverURL,
        series = series ?: found.series,
        narrators = narrators.ifEmpty { description.narrators },
        durationMinutes = durationMinutes ?: description.durationMinutes,
    )
}
