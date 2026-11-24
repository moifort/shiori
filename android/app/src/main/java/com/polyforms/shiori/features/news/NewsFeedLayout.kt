package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.JournalPeriod
import com.polyforms.shiori.shared.account.AccountAvatar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

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

/** The friends' moves of one journal period, under its heading. */
data class FriendSection(val title: String, val moves: List<FriendMove>) {
    val id: String get() = title
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

    /**
     * The friends' moves under their journal periods, newest first, narrowed to one friend when
     * one is picked. Within a period the same move on the same story by several friends is one line.
     */
    fun friendSections(events: List<FeedEvent>, friendId: String? = null, now: Instant = Instant.now()): List<FriendSection> {
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
        return sections.map { (period, moves) -> FriendSection(period.title(now), moves.map { FriendMove(it[0], it.drop(1)) }) }
    }

    fun friendMoves(events: List<FeedEvent>, friendId: String? = null, now: Instant = Instant.now()): List<FriendMove> =
        friendSections(events, friendId, now).flatMap { it.moves }

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
