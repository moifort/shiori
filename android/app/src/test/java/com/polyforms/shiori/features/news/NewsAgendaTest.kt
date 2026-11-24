package com.polyforms.shiori.features.news

import com.polyforms.shiori.shared.BookFormat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.TimeZone

/** The agenda's days, its opening day and its headlines, as iOS's NewsAgendaTests. */
class NewsAgendaTest {
    /** Tuesday 10 November 2026, noon UTC. */
    private val now = Instant.ofEpochSecond(1_794_312_000)

    @Before
    fun utc() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    private fun day(iso: String) = LocalDate.parse(iso)

    private fun release(id: String, date: String?) = UpcomingRelease(id, ReleaseSource.SAGA, BookFormat.BOOK, id, emptyList(), date, null, null, null, null, null, false)

    private fun event(id: String, at: Instant) = FeedEvent(
        id, FeedEventKind.LOVED, at, "marc-$id", "Marc", null, null, id, id, emptyList(), BookFormat.BOOK, null, null, 5.0, 0, false,
    )

    private fun at(iso: String, hours: Long = 0) = day(iso).atStartOfDay().toInstant(ZoneOffset.UTC).plusSeconds(hours * 3600)

    private fun agenda(released: List<UpcomingRelease> = emptyList(), events: List<FeedEvent> = emptyList(), upcoming: List<UpcomingRelease> = emptyList()) =
        NewsAgenda.of(NewsFeedLayout.released(released, emptyList(), null, now), events, upcoming, suggestions = emptyList(), awards = emptyList(), now = now)

    @Test
    fun `only the days with news are in the strip and it opens on today`() {
        val agenda = agenda(released = listOf(release("today", "2026-11-10"), release("old", "2026-10-28")))
        assertEquals(listOf(day("2026-10-28"), day("2026-11-10")), agenda.days.map { it.day })
        assertEquals(day("2026-11-10"), agenda.today)
        assertEquals(day("2026-11-10"), agenda.openingDay)
        assertEquals(listOf("release-today"), agenda.days.last().cards.map { it.id })
    }

    @Test
    fun `each day holds its own news newest first`() {
        val agenda = agenda(
            released = listOf(release("monday", "2026-11-09")),
            events = listOf(event("early", at("2026-11-09", 1)), event("late", at("2026-11-09", 20))),
        )
        assertEquals(listOf("friend-late", "friend-early", "release-monday"), agenda.days.first().cards.map { it.id })
    }

    @Test
    fun `a quiet today opens on the nearest day, the one to come on a tie`() {
        val agenda = agenda(released = listOf(release("before", "2026-11-07")), upcoming = listOf(release("after", "2026-11-13")))
        assertFalse(agenda.days.any { it.day == day("2026-11-10") })
        assertEquals(day("2026-11-13"), agenda.openingDay)
    }

    @Test
    fun `days to come hold every day announced however far`() {
        val agenda = agenda(
            upcoming = listOf(
                release("thursday", "2026-11-12"), release("nextWeek", "2026-11-18"),
                release("month", "2026-12"), release("past", "2026-11-08"), release("far", "2027-01-20"),
            ),
        )
        assertEquals(listOf(day("2026-11-12"), day("2026-11-18"), day("2027-01-20")), agenda.days.map { it.day })
        assertEquals(listOf("upcoming-thursday"), agenda.days.first().cards.map { it.id })
    }

    @Test
    fun `the headlines run twenty days back newest first, then thirty ahead soonest first`() {
        val agenda = agenda(
            released = listOf(release("recent", "2026-11-08"), release("older", "2026-10-25"), release("stale", "2026-10-15")),
            events = listOf(event("friend", at("2026-11-09"))),
            upcoming = listOf(release("later", "2026-12-05"), release("soon", "2026-11-12"), release("month", "2026-12"), release("far", "2026-12-20")),
        )
        assertEquals(
            listOf("friend-friend", "release-recent", "release-older", "upcoming-soon", "upcoming-later"),
            agenda.headlines.map { it.id },
        )
    }

    @Test
    fun `a person's name shortens to its initial and last name`() {
        assertEquals("M. Wells", NewsShelves.shortName("Martha Wells"))
        assertEquals("Moebius", NewsShelves.shortName("Moebius"))
    }

    @Test
    fun `nothing at all is empty`() {
        assert(NewsAgenda.empty(now).isEmpty)
    }
}
