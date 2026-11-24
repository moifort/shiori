package com.polyforms.shiori.features.listening

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ListeningProgressTest {
    private val chapters = listOf(
        ListeningChapter("Ouverture", 0.0, 60.0),
        ListeningChapter("Chapitre 1", 60.0, 600.0),
        ListeningChapter("Chapitre 2", 660.0, 340.0),
    )

    private fun at(elapsed: Double) = ListeningProgress(elapsed, 1000.0, chapters)

    @Test
    fun `names the chapter by its place, the time in it and what is left of it`() {
        val progress = at(360.0)
        assertEquals(2, progress.chapterNumber)
        assertEquals(300.0, progress.chapterElapsed, 0.0)
        assertEquals(300.0, progress.chapterRemaining, 0.0)
        assertEquals(0.5, progress.chapterFraction, 0.0)
        assertEquals(640.0, progress.remaining, 0.0)
        assertEquals(36, progress.percent)
    }

    @Test
    fun `counts a position a hair before a chapter as that chapter`() {
        assertEquals(3, at(659.8).chapterNumber)
    }

    @Test
    fun `previous goes to the chapter's start, or the one before within its first seconds`() {
        assertEquals(60.0, at(400.0).previousChapterStart, 0.0)
        assertEquals(0.0, at(62.0).previousChapterStart, 0.0)
        assertEquals(0.0, at(1.0).previousChapterStart, 0.0)
    }

    @Test
    fun `next goes to the following chapter, and nowhere from the last`() {
        assertEquals(660.0, at(100.0).nextChapterStart)
        assertNull(at(700.0).nextChapterStart)
    }

    @Test
    fun `without chapters, the bar runs over the whole recording`() {
        val progress = ListeningProgress(250.0, 1000.0, emptyList())
        assertNull(progress.chapterNumber)
        assertEquals(0.25, progress.chapterFraction, 0.0)
        assertEquals(750.0, progress.chapterRemaining, 0.0)
    }

    @Test
    fun `the board's figures, chapter 12 of 40, 18 42 in, 46 percent heard`() {
        val progress = ListeningProgress.preview
        assertEquals(12, progress.chapterNumber)
        assertEquals("18:42", ListeningText.clock(progress.chapterElapsed))
        assertEquals("9:16", ListeningText.clock(progress.chapterRemaining))
        assertEquals(46, progress.percent)
    }

    @Test
    fun `a clock position, with hours only past an hour`() {
        assertEquals("0:00", ListeningText.clock(0.0))
        assertEquals("18:42", ListeningText.clock(1122.9))
        assertEquals("1:02:05", ListeningText.clock(3725.0))
    }

    @Test
    fun `the folded bar's line, the chapter, short, and the time left with no word`() {
        assertEquals(L("Chap. %lld · %@", 12, "11h47"), ListeningText.shortLine(ListeningProgress.preview))
    }

    @Test
    fun `what is left, in hours and minutes, or minutes alone`() {
        assertEquals(L("%lldh%@ restantes", 11, "47"), ListeningText.remaining(42420.0))
        assertEquals(L("%lld min restantes", 47), ListeningText.remaining(2801.0))
    }

    private fun book(format: BookFormat, asin: String?) =
        Book(id = "b1", title = "Endymion", authors = listOf("Dan Simmons"), format = format, audibleAsin = asin, status = ReadingStatus.TO_READ)

    @Test
    fun `an audiobook imported from Audible plays its ASIN`() {
        val title = ListeningTitle.of(book(BookFormat.AUDIOBOOK, "B077PLB5KD"))
        assertEquals("B077PLB5KD", title?.asin)
        assertEquals("b1", title?.bookID)
    }

    @Test
    fun `a paper book, or an audiobook with no linked Audible account, plays nothing`() {
        assertNull(ListeningTitle.of(book(BookFormat.BOOK, "B077PLB5KD")))
        assertNull(ListeningTitle.of(book(BookFormat.AUDIOBOOK, null)))
    }

    private fun state(status: ReadingStatus, progress: Int? = null, current: Boolean = false, playing: Boolean = false) =
        ListeningButtonState.of(status, progress, current, playing)

    @Test
    fun `never opened, listen`() {
        assertEquals(ListeningButtonState.LISTEN, state(ReadingStatus.TO_READ))
        assertEquals(ListeningButtonState.LISTEN, state(ReadingStatus.TO_READ, progress = 0))
    }

    @Test
    fun `under way, here or on Audible, resume`() {
        assertEquals(ListeningButtonState.RESUME, state(ReadingStatus.READING))
        assertEquals(ListeningButtonState.RESUME, state(ReadingStatus.TO_READ, progress = 12))
    }

    @Test
    fun `finished, hear it again`() {
        assertEquals(ListeningButtonState.RELISTEN, state(ReadingStatus.READ, progress = 100))
    }

    @Test
    fun `playing in Shiori, pause, whatever the status, and paused there, resume`() {
        assertEquals(ListeningButtonState.PAUSE, state(ReadingStatus.READ, current = true, playing = true))
        assertEquals(ListeningButtonState.PAUSE, state(ReadingStatus.TO_READ, current = true, playing = true))
        assertEquals(ListeningButtonState.RESUME, state(ReadingStatus.READ, current = true))
    }
}
