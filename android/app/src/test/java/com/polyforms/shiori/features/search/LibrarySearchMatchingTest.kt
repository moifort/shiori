package com.polyforms.shiori.features.search

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LibrarySearchMatchingTest {
    private fun book(id: String, title: String, author: String, saga: String? = null, volume: Int? = null) = Book(
        id = id,
        title = title,
        authors = listOf(author),
        series = saga?.let { SeriesMembership("s-$it", it, volume, VolumeKind.MAIN) },
        status = ReadingStatus.READ,
    )

    private val library = listOf(
        book("1", "Le Nom du vent", "Patrick Rothfuss", "Chronique du tueur de roi", 1),
        book("2", "La Peur du sage", "Patrick Rothfuss", "Chronique du tueur de roi", 2),
        book("3", "Dune", "Frank Herbert"),
    ).map(::SearchEntry)

    @Test
    fun `finds a book by the start of a title word, accents folded`() {
        assertEquals(listOf("3"), LibrarySearchMatcher.results("dun", library, SearchFilter()).books.map { it.id })
        assertEquals(listOf("2"), LibrarySearchMatcher.results("peur", library, SearchFilter()).books.map { it.id })
    }

    @Test
    fun `forgives one typo from four letters`() {
        assertEquals(listOf("1", "2"), LibrarySearchMatcher.results("rothfus", library, SearchFilter()).books.map { it.id })
        assertTrue(LibrarySearchMatcher.results("dne", library, SearchFilter()).books.isEmpty())
    }

    @Test
    fun `finds a volume by its number within its saga`() {
        assertEquals(listOf("2"), LibrarySearchMatcher.results("chronique 2", library, SearchFilter()).books.map { it.id })
    }

    @Test
    fun `proposes the saga a query names`() {
        val hits = LibrarySearchMatcher.results("tueur", library, SearchFilter()).series
        assertEquals(listOf("Chronique du tueur de roi"), hits.map { it.name })
    }

    @Test
    fun `counts the books a filter hides`() {
        val results = LibrarySearchMatcher.results("rothfuss", library, SearchFilter(favorites = true))
        assertEquals(0, results.books.size)
        assertEquals(2, results.hiddenByFilter)
    }
}
