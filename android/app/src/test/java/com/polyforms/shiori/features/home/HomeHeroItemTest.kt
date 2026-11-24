package com.polyforms.shiori.features.home

import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.home.components.organisms.HomeHeroItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class HomeHeroItemTest {
    private val today = LocalDate.of(2026, 10, 14)

    @Test
    fun `closes on the call to rate when nothing is rated`() {
        val unrated = MonthlyDiscoveries("2026-10", MonthlyDiscoveries.Status.NONE, emptyList(), needsRatings = true)
        val items = HomeHeroItem.items(emptyList(), emptyList(), needsRatingsMonth = unrated.needsRatingsMonth, today = today)
        assertEquals(listOf("needs-ratings-2026-10"), items.map { it.id })
        val rated = MonthlyDiscoveries("2026-10", MonthlyDiscoveries.Status.READY, emptyList())
        assertNull(rated.needsRatingsMonth)
    }

    @Test
    fun `a month all answered has no hero page`() {
        val done = MonthlyDiscoveries("2026-10", MonthlyDiscoveries.Status.READY, emptyList())
        val items = HomeHeroItem.items(emptyList(), done.shownOnHome, needsRatingsMonth = done.needsRatingsMonth, today = today)
        assertTrue(items.isEmpty())
    }

    @Test
    fun `a prompt closes the line and stands alone when nothing else does`() {
        val unrated = MonthlyDiscoveries("2026-10", MonthlyDiscoveries.Status.NONE, emptyList(), needsRatings = true)
        val items = HomeHeroItem.items(emptyList(), emptyList(), needsRatingsMonth = unrated.needsRatingsMonth, prompt = HomePrompt.KINDLE, today = today)
        assertEquals("prompt-kindle", items.last().id)
        val alone = HomeHeroItem.items(emptyList(), emptyList(), prompt = HomePrompt.FRIENDS, today = today)
        assertEquals(listOf("prompt-friends"), alone.map { it.id })
    }
}
