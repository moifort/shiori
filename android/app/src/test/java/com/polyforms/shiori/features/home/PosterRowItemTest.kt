package com.polyforms.shiori.features.home

import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.PosterLabel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PosterRowItemTest {
    private val book = Book(id = "awaited-1", title = "La sanction", authors = listOf("Vanian"), format = BookFormat.AUDIOBOOK, status = ReadingStatus.TO_READ)

    @Test
    fun `a trailing lambda is what the tap runs, with a caption`() {
        val opened = mutableListOf<String>()
        val item = PosterRowItem(book, "Disponible") { opened += "own" }
        assertNull(item.dropWished)
        item.tap { opened += "row" }
        assertEquals(listOf("own"), opened)
    }

    @Test
    fun `a trailing lambda is what the tap runs, with a label`() {
        val opened = mutableListOf<String>()
        val item = PosterRowItem(book, PosterLabel("24 déc.")) { opened += "own" }
        assertNull(item.dropWished)
        item.tap { opened += "row" }
        assertEquals(listOf("own"), opened)
    }

    @Test
    fun `without its own open, the tap goes to the row with the book`() {
        val opened = mutableListOf<Book>()
        PosterRowItem(book, "Disponible").tap { opened += it }
        assertEquals(listOf(book), opened)
    }
}
