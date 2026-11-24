package com.polyforms.shiori.features.listening

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ListeningPositionsTest {
    private val earlier = Instant.ofEpochSecond(1_000)
    private val later = Instant.ofEpochSecond(2_000)

    private fun store() = ListeningPositions(KeyValueStore.InMemory())

    @Test
    fun `a position saved offline waits until it is sent`() {
        val positions = store()
        positions.record("B1", 120.0, "CR!1", earlier)
        assertEquals(listOf("B1"), positions.pending().keys.sorted())
        positions.markSent("B1", earlier)
        assertTrue(positions.pending().isEmpty())
        assertEquals(120.0, positions.entry("B1")?.position)
    }

    @Test
    fun `a later save is not marked sent by an earlier one's answer`() {
        val positions = store()
        positions.record("B1", 120.0, "CR!1", earlier)
        positions.record("B1", 180.0, "CR!1", later)
        positions.markSent("B1", earlier)
        assertEquals(180.0, positions.pending()["B1"]?.position)
    }

    @Test
    fun `resumes from whichever of Audible and the phone saved last`() {
        val local = ListeningPositions.Entry(300.0, "CR!1", later.toEpochMilli(), isPending = true)
        assertEquals(300.0, ListeningPositions.resume(100.0, earlier, local))
        val stale = ListeningPositions.Entry(50.0, "CR!1", earlier.toEpochMilli(), isPending = false)
        assertEquals(100.0, ListeningPositions.resume(100.0, later, stale))
        assertEquals(50.0, ListeningPositions.resume(null, null, stale))
        assertEquals(100.0, ListeningPositions.resume(100.0, null, null))
    }

    @Test
    fun `the title kept is found again, cover and book included`() {
        val last = LastListenedTitle(KeyValueStore.InMemory())
        assertNull(last.value)
        val title = ListeningTitle("B077PLB5KD", "Endymion", "Les Cantos d'Hypérion · Tome 3", "https://example.com/cover.jpg", "book-1")
        last.value = title
        assertEquals(title, last.value)
    }

    @Test
    fun `stopping forgets it`() {
        val last = LastListenedTitle(KeyValueStore.InMemory())
        last.value = ListeningTitle("B1", "Seul sur Mars", null, null)
        last.value = null
        assertNull(last.value)
    }
}
