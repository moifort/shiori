package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.JournalPeriod
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

/** Something out in the last thirty days: a release followed, or a narrator's new recording. */
sealed interface ReleasedItem {
    val day: LocalDate

    data class Release(val release: UpcomingRelease, override val day: LocalDate) : ReleasedItem
    data class Narrator(val news: NarratorNews, override val day: LocalDate) : ReleasedItem

    val id: String
        get() = when (this) {
            is Release -> "release-${release.id}"
            is Narrator -> "narrator-${news.id}"
        }
    val cover: Book get() = when (this) {
        is Release -> release.cover
        is Narrator -> news.cover
    }
    val title: String get() = when (this) {
        is Release -> release.title ?: release.cover.title
        is Narrator -> news.title
    }
    val authors: List<String> get() = when (this) {
        is Release -> release.authors
        is Narrator -> news.authors
    }
    val format: BookFormat get() = if (this is Release) release.format else BookFormat.AUDIOBOOK
    val language: BookLanguage? get() = when (this) {
        is Release -> release.language
        is Narrator -> news.language
    }
    val seriesLine: String? get() = (this as? Release)?.release?.seriesLine
    val shownTitle: String get() = (this as? Release)?.release?.shownTitle ?: title
    val isAwaited: Boolean get() = (this as? Release)?.release?.source == ReleaseSource.AWAITED
    val instant: Instant get() = day.atStartOfDay(ZoneId.systemDefault()).toInstant()

    val draft: BookDraft
        get() = BookDraft(
            title = title,
            authors = authors,
            format = format,
            media = if (format == BookFormat.AUDIOBOOK) emptyList() else listOf(BookMedium.PRINT),
            coverURL = cover.coverURL,
            language = language,
        )
}

/** One friend's move, and the friends who made the same one the same day. */
data class FriendMove(val lead: FeedEvent, val others: List<FeedEvent>) {
    val id: String get() = lead.id
}

/** A friend's face on the stories rail; ringed when they did something new. */
data class FriendStory(val id: String, val name: String, val avatar: AccountAvatar, val isNew: Boolean)

sealed interface NewsFeedItem {
    data class Released(val item: ReleasedItem) : NewsFeedItem
    data class Friend(val move: FriendMove) : NewsFeedItem

    val id: String get() = when (this) {
        is Released -> item.id
        is Friend -> "friend-${move.id}"
    }
    val date: Instant get() = when (this) {
        is Released -> item.instant
        is Friend -> move.lead.at
    }
    val format: BookFormat get() = when (this) {
        is Released -> item.format
        is Friend -> move.lead.format
    }
}

data class NewsFeedSection(val title: String, val items: List<NewsFeedItem>) {
    val id: String get() = title
}

/** How the News feed lays out what came out and what friends did, period by period. */
object NewsFeedLayout {
    const val RELEASED_DAYS = 30L
    val pillFormats = listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK, BookFormat.BANDE_DESSINEE, BookFormat.COMIC, BookFormat.MANGA)

    private fun day(date: String?): LocalDate? {
        val parts = date?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
        if (parts.size < 2) return null
        return runCatching { LocalDate.of(parts[0], parts[1], parts.getOrElse(2) { 1 }) }.getOrNull()
    }

    fun released(releases: List<UpcomingRelease>, narrator: List<NarratorNews>, format: BookFormat?, now: Instant = Instant.now()): List<ReleasedItem> {
        val today = now.atZone(ZoneId.systemDefault()).toLocalDate()
        val since = today.minusDays(RELEASED_DAYS)
        fun inWindow(day: LocalDate) = !day.isBefore(since) && !day.isAfter(today)
        val items = releases.filter { format == null || it.format == format }.mapNotNull { release ->
            day(release.date)?.takeIf(::inWindow)?.let { ReleasedItem.Release(release, it) }
        }.toMutableList<ReleasedItem>()
        val held = items.mapNotNull { (it as? ReleasedItem.Release)?.release?.let { r -> r.title?.let { t -> "${t.lowercase()}~${r.format.name}" } } }.toSet()
        if (format == null || format == BookFormat.AUDIOBOOK) {
            items += narrator.mapNotNull { news ->
                val day = day(news.date)?.takeIf(::inWindow) ?: return@mapNotNull null
                if ("${news.title.lowercase()}~${BookFormat.AUDIOBOOK.name}" in held) null else ReleasedItem.Narrator(news, day)
            }
        }
        return items.sortedByDescending { it.day }
    }

    fun feedSections(released: List<ReleasedItem>, events: List<FeedEvent>, format: BookFormat?, friendId: String?, now: Instant = Instant.now()): List<NewsFeedSection> {
        val since = now.atZone(ZoneId.systemDefault()).toLocalDate().minusDays(RELEASED_DAYS).atStartOfDay(ZoneId.systemDefault()).toInstant()
        val moves = friendMoves(events.filter { it.at >= since && (format == null || it.format == format) }, friendId, now).map(NewsFeedItem::Friend)
        val releases = if (friendId == null) released.map(NewsFeedItem::Released) else emptyList()
        val sections = mutableListOf<Pair<JournalPeriod, MutableList<NewsFeedItem>>>()
        for (item in (moves + releases).sortedByDescending { it.date }) {
            val period = JournalPeriod.of(item.date, now)
            val section = sections.firstOrNull { it.first == period }
            if (section != null) section.second += item else sections += period to mutableListOf(item)
        }
        return sections.map { NewsFeedSection(it.first.title(now), it.second) }
    }

    private fun sameMove(event: FeedEvent) = "${event.kind.name}~${event.title.lowercase()}~${event.authors.firstOrNull()?.lowercase() ?: ""}"

    fun friendMoves(events: List<FeedEvent>, friendId: String? = null, now: Instant = Instant.now()): List<FriendMove> {
        val sections = mutableListOf<Pair<JournalPeriod, MutableList<MutableList<FeedEvent>>>>()
        for (event in events.sortedByDescending { it.at }) {
            if (friendId != null && event.friendId != friendId) continue
            val period = JournalPeriod.of(event.at, now)
            if (sections.lastOrNull()?.first != period) sections += period to mutableListOf()
            val moves = sections.last().second
            val key = sameMove(event)
            val existing = moves.firstOrNull { sameMove(it[0]) == key }
            if (existing != null) existing += event else moves += mutableListOf(event)
        }
        return sections.flatMap { section -> section.second.map { FriendMove(it[0], it.drop(1)) } }
    }

    fun stories(events: List<FeedEvent>, seenAt: Instant?): List<FriendStory> {
        val stories = mutableListOf<FriendStory>()
        for (event in events.sortedByDescending { it.at }) {
            val isNew = seenAt?.let { event.at > it } ?: true
            val index = stories.indexOfFirst { it.id == event.friendId }
            if (index >= 0) {
                if (isNew && !stories[index].isNew) stories[index] = FriendStory(event.friendId, event.friendName, event.avatar, true)
                continue
            }
            stories += FriendStory(event.friendId, event.friendName, event.avatar, isNew)
        }
        return stories
    }

    fun pillFormats(feed: List<NewsFeedSection>, selected: BookFormat?): List<BookFormat> {
        val present = feed.flatMap { it.items }.map { it.format }.toSet()
        return pillFormats.filter { it in present || it == selected }
    }
}

/** A day of the release calendar, or a month or year without one. */
data class ReleaseDay(val id: String, val weekday: String?, val label: String, val symbol: String? = null, val releases: List<UpcomingRelease>)

data class ReleaseMonthSection(val id: String, val title: String, val days: List<ReleaseDay>)

/** The releases to come, filed by month and day, then the later years, the undated, the awaited. */
class ReleaseCalendar(val releases: List<UpcomingRelease>, private val now: Instant = Instant.now()) {
    private data class Parsed(val year: Int, val month: Int?, val day: Int?)

    private fun parsed(date: String?): Parsed? {
        val parts = date?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
        val year = parts.firstOrNull() ?: return null
        return Parsed(year, parts.getOrNull(1), parts.getOrNull(2))
    }

    val dated: List<UpcomingRelease> get() = sections.filter { it.id != BEYOND && it.id != AWAITED }.flatMap { it.days.flatMap { day -> day.releases } }

    val sections: List<ReleaseMonthSection>
        get() {
            val locale = Locale.getDefault()
            val today = now.atZone(ZoneId.systemDefault()).toLocalDate()
            data class Month(val start: LocalDate, val days: MutableMap<Int, MutableList<UpcomingRelease>> = sortedMapOf(), val monthOnly: MutableList<UpcomingRelease> = mutableListOf())
            val months = sortedMapOf<String, Month>()
            val years = sortedMapOf<Int, MutableList<UpcomingRelease>>()
            val undated = mutableListOf<UpcomingRelease>()
            val waiting = mutableListOf<UpcomingRelease>()
            for (release in releases) {
                val date = parsed(release.date)
                if (date == null) {
                    if (release.source == ReleaseSource.AWAITED) waiting += release else undated += release
                    continue
                }
                val month = date.month
                if (month == null) {
                    if (date.year >= today.year) years.getOrPut(date.year) { mutableListOf() } += release
                    continue
                }
                val start = runCatching { LocalDate.of(date.year, month, 1) }.getOrNull() ?: continue
                val key = "%04d-%02d".format(date.year, month)
                val day = date.day
                if (day != null) {
                    val whenDay = runCatching { LocalDate.of(date.year, month, day) }.getOrNull() ?: continue
                    if (whenDay.isBefore(today)) continue
                    months.getOrPut(key) { Month(start) }.days.getOrPut(day) { mutableListOf() } += release
                } else {
                    if (!start.plusMonths(1).isAfter(today)) continue
                    months.getOrPut(key) { Month(start) }.monthOnly += release
                }
            }
            val sections = months.map { (key, entry) ->
                val days = entry.days.map { (day, list) ->
                    val whenDay = entry.start.withDayOfMonth(day)
                    ReleaseDay("$key-$day", whenDay.dayOfWeek.getDisplayName(TextStyle.SHORT, locale), day.toString(), releases = list)
                }.toMutableList()
                if (entry.monthOnly.isNotEmpty()) days += ReleaseDay("$key-month", null, L("Sans jour"), releases = entry.monthOnly)
                var title = entry.start.month.getDisplayName(TextStyle.FULL_STANDALONE, locale).replaceFirstChar { it.titlecase(locale) }
                if (entry.start.year != today.year) title += " ${entry.start.year}"
                ReleaseMonthSection(key, title, days)
            }.toMutableList()
            val beyond = years.map { (year, list) -> ReleaseDay("year-$year", null, year.toString(), releases = list) }.toMutableList()
            if (undated.isNotEmpty()) beyond += ReleaseDay("undated", null, L("Sans date"), releases = undated)
            if (beyond.isNotEmpty()) sections += ReleaseMonthSection(BEYOND, L("Au-delà"), beyond)
            if (waiting.isNotEmpty()) sections += ReleaseMonthSection(AWAITED, L("Guettés, pas encore annoncés"), listOf(ReleaseDay("awaited", null, "", "binoculars", waiting)))
            return sections
        }

    companion object {
        private const val BEYOND = "beyond"
        private const val AWAITED = "awaited"
    }
}
