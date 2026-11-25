package com.polyforms.shiori.features.goodreads

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import java.time.Instant

/** The Goodreads shelf a book sits on: every book is on exactly one of these. */
enum class GoodreadsShelf { READ, CURRENTLY_READING, TO_READ }

/** How a row of the export stands against the library. */
enum class GoodreadsVerdict { NEW, HELD, UNCERTAIN }

/** One book of a Goodreads export, read by the server, before anything is saved. */
data class GoodreadsRow(
    val key: String,
    val title: String,
    val authors: List<String>,
    val seriesName: String? = null,
    val volume: Int? = null,
    val format: BookFormat = BookFormat.BOOK,
    val media: List<BookMedium> = listOf(BookMedium.PRINT),
    val language: BookLanguage? = null,
    val rating: Double? = null,
    val readOn: Instant? = null,
    val shelf: GoodreadsShelf,
    val dropped: Boolean = false,
    val hasReview: Boolean = false,
    val verdict: GoodreadsVerdict,
    val heldBookId: String? = null,
    val heldTitle: String? = null,
    val heldCoverURL: String? = null,
    val coverURL: String? = null,
) {
    /** The status the row lands with, or null when it goes to the wishlist. */
    fun status(toRead: GoodreadsChoices.ToRead): ReadingStatus? = when {
        dropped -> ReadingStatus.DROPPED
        shelf == GoodreadsShelf.READ -> ReadingStatus.READ
        shelf == GoodreadsShelf.CURRENTLY_READING -> ReadingStatus.READING
        toRead == GoodreadsChoices.ToRead.PILE -> ReadingStatus.TO_READ
        else -> null
    }

    /** Drawn as the shelves draw a book: its cover, else the app's typeset stand-in. */
    val cover: Book get() = Book(id = "goodreads-$key", title = title, authors = authors, format = format, media = media, language = language, coverURL = coverURL, status = ReadingStatus.TO_READ)

    /** The record it would complete, as the "same book?" sheet shows it. */
    val heldCover: Book?
        get() = if (heldBookId != null && heldTitle != null) Book(id = heldBookId, title = heldTitle, authors = authors, coverURL = heldCoverURL, status = ReadingStatus.TO_READ) else null

    /** Under its cover, how it lands: "Lu", "En cours", "Envie"… */
    fun caption(toRead: GoodreadsChoices.ToRead): String = when (status(toRead)) {
        ReadingStatus.READ -> L("Lu")
        ReadingStatus.READING -> L("En cours")
        ReadingStatus.DROPPED -> L("Abandonné")
        ReadingStatus.TO_READ -> L("À lire")
        null -> L("Envie")
    }
}

/** What a Goodreads export holds, against the library. */
data class GoodreadsPreview(
    val rows: List<GoodreadsRow>,
    val readCount: Int,
    val readingCount: Int,
    val toReadCount: Int,
    val droppedCount: Int,
    val ratedCount: Int,
    val datedCount: Int,
    val reviewedCount: Int,
) {
    val newRows: List<GoodreadsRow> get() = rows.filter { it.verdict == GoodreadsVerdict.NEW }
    val heldRows: List<GoodreadsRow> get() = rows.filter { it.verdict == GoodreadsVerdict.HELD }
    val uncertainRows: List<GoodreadsRow> get() = rows.filter { it.verdict == GoodreadsVerdict.UNCERTAIN }
}

/** What the reader decides before the import. */
data class GoodreadsChoices(
    val keys: Set<String>,
    val toRead: ToRead = ToRead.WISHLIST,
    val keepRatings: Boolean = true,
    val keepDates: Boolean = true,
    val keepReviews: Boolean = true,
    val sameBooks: Set<String> = emptySet(),
) {
    enum class ToRead { WISHLIST, PILE }

    /** How many rows an import would write. */
    fun importedCount(preview: GoodreadsPreview): Int =
        preview.rows.count { it.key in keys && it.verdict != GoodreadsVerdict.HELD && it.key !in sameBooks }

    companion object {
        /** Every new and held row, the uncertain left for the reader. */
        fun of(preview: GoodreadsPreview) = GoodreadsChoices(keys = preview.rows.filter { it.verdict != GoodreadsVerdict.UNCERTAIN }.map { it.key }.toSet())
    }
}

data class GoodreadsImportOutcome(val imported: Int, val completed: Int, val wished: Int, val pendingCovers: Int)

data class GoodreadsImportSummary(val importedAt: Instant?, val imported: Int, val completed: Int, val wished: Int, val pendingCovers: Int, val withoutCover: Int)

/** Why a file could not be read. */
class GoodreadsFileError(val kind: Kind) : Exception(kind.name) {
    enum class Kind { NOT_GOODREADS, EMPTY, UNREADABLE }
}

/** Where the reader exports the file, opened in the browser. */
const val GOODREADS_EXPORT_URL = "https://www.goodreads.com/review/import"
