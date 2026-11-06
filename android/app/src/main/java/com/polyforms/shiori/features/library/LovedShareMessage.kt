package com.polyforms.shiori.features.library

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import java.text.Collator
import java.text.Normalizer

/** The loved books and sagas as a message to send, by genre then format. */
object LovedShareMessage {
    private data class Entry(val genre: BookGenre?, val format: BookFormat, val name: String, val author: String?, val isSeries: Boolean) {
        val key: String
            get() {
                val folded = Normalizer.normalize(name.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}"), "")
                return "${if (isSeries) "series" else "book"}|${format.name}|$folded"
            }
        val line: String
            get() {
                val title = if (isSeries) L("%@ (série)", name) else name
                return if (author.isNullOrEmpty()) "• $title" else "• $title — $author"
            }
    }

    private fun entry(genre: BookGenre?, format: BookFormat, name: String, author: String?, isSeries: Boolean) =
        Entry(genre, if (format == BookFormat.AUDIOBOOK) BookFormat.BOOK else format, name, author, isSeries)

    fun text(books: List<Book>, series: List<FollowedSeries>): String {
        val entries = mutableListOf<Entry>()
        val seen = mutableSetOf<String>()
        fun add(entry: Entry) {
            if (seen.add(entry.key)) entries += entry
        }
        series.forEach { add(entry(it.genre, it.volumes.firstOrNull()?.format ?: BookFormat.BOOK, it.name, it.author, true)) }
        books.forEach { book ->
            val membership = book.series
            if (membership != null && membership.name.isNotEmpty()) {
                add(entry(book.genre, book.format, membership.name, book.authors.firstOrNull(), true))
            } else {
                add(entry(book.genre, book.format, book.title, book.authors.ifEmpty { null }?.joinToString(", "), false))
            }
        }
        val collator = Collator.getInstance()
        val lines = mutableListOf(L("Mes coups de cœur 📚"))
        val byGenre = entries.groupBy { it.genre ?: BookGenre.OTHER }
        for (genre in BookGenre.alphabetical) {
            val ofGenre = byGenre[genre] ?: continue
            lines += listOf("", "*${genre.label}*")
            val byFormat = ofGenre.groupBy { it.format }
            val formats = BookFormat.entries.filter { byFormat[it] != null }
            for (format in formats) {
                if (formats.size > 1 || format != BookFormat.BOOK) lines += "_${format.label}_"
                lines += byFormat.getValue(format)
                    .sortedWith { l, r -> if (l.isSeries != r.isSeries) (if (l.isSeries) -1 else 1) else collator.compare(l.name, r.name) }
                    .map { it.line }
            }
        }
        return lines.joinToString("\n")
    }
}
