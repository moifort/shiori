package com.polyforms.shiori.features.friends

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.L
import java.text.Collator

/**
 * The reader's favourites as plain text, to send or to copy: one part per format, then one
 * section per genre within it, its sagas then its books, one line each — "Title — Author —
 * Subgenre". Any part the record does not know is left out; a favourite with no genre goes under
 * "Autres", last.
 */
object FavoritesSharing {
    /** A shelf's favourites as text; null when nothing is hearted. */
    fun text(shelf: FriendProfile): String? {
        if (shelf.favoriteSagas.isEmpty() && shelf.favorites.isEmpty()) return null
        return text(shelf.favoriteSagas, shelf.favorites.map { it.book })
    }

    fun text(sagas: List<FriendSaga>, books: List<Book>): String {
        // A saga held in two languages is two rows on the shelf, but one work to recommend.
        val seen = mutableSetOf<String>()
        val sagaEntries = sagas.mapNotNull { saga ->
            val format = format(saga)
            if (!seen.add("${saga.name}\u0000${saga.author ?: ""}\u0000$format")) return@mapNotNull null
            Entry(format, saga.genre, line(saga.name, true, saga.author, saga.subgenre))
        }
        val bookEntries = books.map {
            Entry(it.format, it.genre, line(it.title, false, if (it.authors.isEmpty()) null else it.authorLine, it.subgenres.firstOrNull()))
        }
        val entries = sagaEntries + bookEntries
        val parts = BookFormat.entries.mapNotNull { format ->
            val held = entries.filter { it.format == format }
            if (held.isEmpty()) null else (listOf(heading(format).uppercase()) + genreSections(held)).joinToString("\n\n")
        }
        return (listOf(L("Mes favoris")) + parts).joinToString("\n\n")
    }

    private data class Entry(val format: BookFormat, val genre: BookGenre?, val line: String)

    private fun genreSections(entries: List<Entry>): List<String> {
        val collator = Collator.getInstance()
        val genres = entries.mapNotNull { it.genre }.toSet().sortedWith { a, b -> collator.compare(a.label, b.label) }
        val sections = genres.map { genre -> section(genre.label, entries.filter { it.genre == genre }) }.toMutableList()
        val unclassified = entries.filter { it.genre == null }
        if (unclassified.isNotEmpty()) sections += section(L("Autres"), unclassified)
        return sections
    }

    /** A saga is what most of its volumes are; one with no volume is a novel, or a recording. */
    private fun format(saga: FriendSaga): BookFormat {
        val formats = saga.volumes.map { it.format }
        // A tie goes to the format listed first, so the text does not change between sends.
        return BookFormat.entries.filter { it in formats }.maxByOrNull { f -> formats.count { it == f } }
            ?: if (saga.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
    }

    private fun heading(format: BookFormat): String = when (format) {
        BookFormat.BOOK -> L("Livres")
        BookFormat.AUDIOBOOK -> L("Livres audio")
        BookFormat.BANDE_DESSINEE -> L("BD")
        BookFormat.COMIC -> L("Comics")
        BookFormat.MANGA -> L("Mangas")
    }

    private fun section(heading: String, entries: List<Entry>) = (listOf(heading) + entries.map { it.line }).joinToString("\n")

    private fun line(title: String, isSaga: Boolean, author: String?, subgenre: String?): String {
        val name = if (isSaga) L("%@ (série)", title) else title
        return "• " + listOfNotNull(name, author, subgenre).joinToString(" — ")
    }
}
