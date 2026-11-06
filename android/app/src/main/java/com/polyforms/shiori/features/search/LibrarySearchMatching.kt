package com.polyforms.shiori.features.search

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import java.text.Normalizer
import java.time.Instant

/** Text folded as the search compares it: no case, no accents, words split on anything else. */
object SearchText {
    fun normalized(text: String): String {
        val folded = Normalizer.normalize(text.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")
        return folded.map { if (it.isLetterOrDigit()) it else ' ' }.joinToString("").split(' ').filter { it.isNotEmpty() }.joinToString(" ")
    }

    fun words(text: String): List<String> = normalized(text).split(' ').filter { it.isNotEmpty() }
}

/** A book with its words, folded once when the index is built. */
data class SearchEntry(val book: Book) {
    val id: String get() = book.id
    val titleWords: List<String> = SearchText.words(book.title)
    private val authorWords = book.authors.flatMap { SearchText.words(it) }
    private val sagaWords = book.series?.let { SearchText.words(it.name) }.orEmpty()
    val otherWords: List<String> = authorWords + sagaWords
    val seriesWords: List<String> = sagaWords + authorWords
}

data class SearchFilter(val favorites: Boolean = false, val status: ReadingStatus? = null) {
    val isActive: Boolean get() = favorites || status != null
    fun keeps(book: Book): Boolean = (!favorites || book.favorite) && (status == null || book.status == status)

    companion object {
        val statuses = listOf(ReadingStatus.READING, ReadingStatus.TO_READ, ReadingStatus.READ)
    }
}

data class SeriesHit(val id: String, val name: String, val authors: List<String>, val books: List<Book>)

data class SearchResults(val series: List<SeriesHit> = emptyList(), val books: List<Book> = emptyList(), val hiddenByFilter: Int = 0) {
    companion object {
        val empty = SearchResults()
    }
}

/**
 * Matches what is typed against the library on the phone: each word a prefix of a word of the
 * title, else of the authors or the saga, one typo forgiven from four letters; the best first.
 */
object LibrarySearchMatcher {
    const val MAX_SERIES = 3
    const val SHORTEST_FORGIVEN = 4

    private data class Score(val edits: Int, val outsideTitle: Int) : Comparable<Score> {
        override fun compareTo(other: Score) = compareValuesBy(this, other, { it.edits }, { it.outsideTitle })
    }

    fun results(query: String, entries: List<SearchEntry>, filter: SearchFilter): SearchResults {
        val words = SearchText.words(query)
        if (words.isEmpty()) {
            if (!filter.isActive) return SearchResults.empty
            return SearchResults(books = entries.map { it.book }.filter(filter::keeps).sortedByDescending { it.shelvedAt ?: Instant.MIN })
        }
        val memo = HashMap<Pair<Int, String>, Int>()
        val matches = mutableListOf<Pair<SearchEntry, Score>>()
        var hidden = 0
        for (entry in entries) {
            val score = score(entry, words, memo) ?: continue
            if (filter.keeps(entry.book)) matches += entry to score else hidden++
        }
        matches.sortWith { a, b -> if (a.second != b.second) a.second.compareTo(b.second) else sagaOrder.compare(a.first.book, b.first.book) }
        return SearchResults(seriesHits(words, entries, filter, memo), matches.map { it.first.book }, hidden)
    }

    fun highlights(titleWord: String, query: String): Boolean {
        val candidate = SearchText.normalized(titleWord)
        if (candidate.isEmpty()) return false
        return SearchText.words(query).any { quality(it, candidate) != null }
    }

    private fun memoQuality(memo: MutableMap<Pair<Int, String>, Int>, position: Int, word: String, candidate: String): Int? {
        val key = position to candidate
        memo[key]?.let { return if (it < 0) null else it }
        val found = quality(word, candidate)
        memo[key] = found ?: -1
        return found
    }

    private fun score(entry: SearchEntry, words: List<String>, memo: MutableMap<Pair<Int, String>, Int>): Score? {
        var edits = 0
        var outside = 0
        words.forEachIndexed { position, word ->
            val inTitle = best(position, word, entry.titleWords, memo)
            if (inTitle != null) {
                edits += inTitle
                return@forEachIndexed
            }
            val elsewhere = best(position, word, entry.otherWords, memo)
            if (elsewhere != null) {
                edits += elsewhere
                outside++
                return@forEachIndexed
            }
            val volume = word.toIntOrNull()
            if (volume != null && entry.book.series?.volume == volume) {
                outside++
                return@forEachIndexed
            }
            return null
        }
        return Score(edits, outside)
    }

    private fun best(position: Int, word: String, candidates: List<String>, memo: MutableMap<Pair<Int, String>, Int>): Int? {
        var best: Int? = null
        for (candidate in candidates) {
            val edit = memoQuality(memo, position, word, candidate) ?: continue
            if (edit == 0) return 0
            best = edit
        }
        return best
    }

    private fun quality(typed: String, held: String): Int? {
        if (held.startsWith(typed)) return 0
        if (typed.length < SHORTEST_FORGIVEN) return null
        if (isOneEditAway(typed, held)) return 1
        if (held.length > typed.length && isOneEditAway(typed, held.take(typed.length))) return 1
        return null
    }

    private fun isOneEditAway(a: String, b: String): Boolean {
        val (short, long) = if (a.length <= b.length) a to b else b to a
        if (long.length - short.length > 1) return false
        var i = 0
        var j = 0
        var edited = false
        while (i < short.length && j < long.length) {
            if (short[i] == long[j]) {
                i++
                j++
                continue
            }
            if (edited) return false
            edited = true
            if (short.length == long.length) i++
            j++
        }
        return edited || long.length != short.length
    }

    private fun seriesHits(words: List<String>, entries: List<SearchEntry>, filter: SearchFilter, memo: MutableMap<Pair<Int, String>, Int>): List<SeriesHit> {
        val bySaga = entries.filter { it.book.series != null }.groupBy { it.book.series!!.id }
        val hits = mutableListOf<Pair<SeriesHit, Int>>()
        for ((id, volumes) in bySaga) {
            val first = volumes.first()
            val name = first.book.series?.name ?: continue
            val total = words.mapIndexed { p, w -> best(p, w, first.seriesWords, memo) }
            if (total.any { it == null }) continue
            val kept = volumes.map { it.book }.filter(filter::keeps).sortedWith(sagaOrder)
            if (kept.isEmpty()) continue
            hits += SeriesHit(id, name, first.book.authors, kept) to total.sumOf { it ?: 0 }
        }
        return hits.sortedWith(compareBy<Pair<SeriesHit, Int>> { it.second }.thenBy { it.first.name }).take(MAX_SERIES).map { it.first }
    }

    private val sagaOrder: Comparator<Book> = compareBy<Book>({ it.series?.name ?: "" }, { it.series?.volume ?: Int.MAX_VALUE }, { it.title })
}
