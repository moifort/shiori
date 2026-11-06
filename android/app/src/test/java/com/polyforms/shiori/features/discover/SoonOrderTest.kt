package com.polyforms.shiori.features.discover

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class SoonOrderTest {
    private fun edition(id: String, state: AwaitedState, date: String?, awaitedAt: Long = 0) = AwaitedEdition(
        id, ReleaseFormat.BOOK, state, id, id, null, emptyList(), date, null, null, Instant.ofEpochSecond(awaitedAt), null, "me",
    )

    @Test
    fun `announced soonest first, then out newest first, then looked for latest awaited first`() {
        val editions = listOf(
            edition("looked-old", AwaitedState.UNANNOUNCED, null, 1),
            edition("out-old", AwaitedState.AVAILABLE, "2026-01-10"),
            edition("coming-late", AwaitedState.ANNOUNCED, "2026-12-20"),
            edition("looked-new", AwaitedState.UNANNOUNCED, null, 5),
            edition("coming-soon", AwaitedState.ANNOUNCED, "2026-11-20"),
            edition("out-new", AwaitedState.AVAILABLE, "2026-10-01"),
            edition("coming-undated", AwaitedState.ANNOUNCED, null),
        )

        assertEquals(
            listOf("coming-soon", "coming-late", "coming-undated", "out-new", "out-old", "looked-new", "looked-old"),
            editions.soonOrder.map { it.id },
        )
    }
}
