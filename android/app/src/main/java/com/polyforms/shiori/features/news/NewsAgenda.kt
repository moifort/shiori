package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.AwardWinner
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.components.molecules.TakenState
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.abs

/**
 * One book of the Découvrir agenda, whatever brought it: a friend's move, a release among what
 * the reader follows, the month's discovery or a prize. The cover carries the book; the card only
 * says why it is there.
 */
sealed interface NewsCard {
    data class Friend(val move: FriendMove) : NewsCard
    data class Released(val item: ReleasedItem) : NewsCard
    data class Upcoming(val release: UpcomingRelease) : NewsCard
    data class Discovery(val suggestion: Suggestion) : NewsCard
    data class Award(val winner: AwardWinner) : NewsCard

    val id: String
        get() = when (this) {
            is Friend -> "friend-${move.id}"
            is Released -> item.id
            is Upcoming -> "upcoming-${release.id}"
            is Discovery -> "suggestion-${suggestion.id}"
            is Award -> "award-${winner.id}"
        }

    /** What `taken`, `wished` and `dismissed` remember it by: a friend's book by its book id. */
    val key: String get() = if (this is Friend) move.lead.bookId else id

    val cover: Book
        get() = when (this) {
            is Friend -> move.lead.cover
            is Released -> item.cover
            is Upcoming -> release.cover
            is Discovery -> suggestion.cover
            is Award -> winner.cover
        }

    /** When it happened, for the day the agenda files it under; null for what has no day. */
    val date: Instant?
        get() = when (this) {
            is Friend -> move.lead.at
            is Released -> item.instant
            else -> null
        }

    /**
     * The awaited edition an announced card of the wish list's rail stands for: its id is the
     * server's `awaited~<editionId>`.
     */
    val awaitedEditionId: String?
        get() {
            val release = (this as? Upcoming)?.release ?: return null
            if (release.source != ReleaseSource.AWAITED) return null
            val parts = release.id.split("~", limit = 2)
            return if (parts.size == 2 && parts[0] == "awaited") parts[1] else null
        }

    /**
     * Whether the server says the reader holds the book already, in any format: a friend's book, a
     * prize's winner. The other cards are of books the server leaves out once held.
     */
    val inLibrary: Boolean
        get() = when (this) {
            is Friend -> move.lead.inLibrary
            is Award -> winner.inLibrary ?: false
            else -> false
        }

    /** A "Pas intéressé" the server keeps: the month's discovery and a prize. */
    val isDismissable: Boolean get() = this is Discovery || this is Award
}

/**
 * One day of the agenda and what it brought: the friends' moves and the releases dated to it,
 * and on today the month's discovery.
 */
data class NewsAgendaDay(val day: LocalDate, val cards: List<NewsCard>) {
    val id: LocalDate get() = day
}

/**
 * The Découvrir page as an agenda: "À la une" first, the releases of what the reader follows a
 * few days back and ahead mixed with the friends' latest moves; then only the days that bring
 * something, a month back and every announced day ahead; then the shelves of each follow, and the
 * year's prizes. Pure: the same loads and the same day always give the same agenda.
 */
data class NewsAgenda(
    /** The days with news, oldest first. */
    val days: List<NewsAgendaDay>,
    val today: LocalDate,
    /** "À la une": the friends' coups de cœur and the releases out lately, then what is due soon. */
    val headlines: List<NewsShelfItem>,
    /** The winners crowned this year, the latest prize first; none hides the section. */
    val prizes: List<NewsCard>,
    /** The rails under the agenda: friends' favourites, series, authors, narrators, wishes. */
    val shelves: NewsShelves = NewsShelves.empty,
    /** Whether the reader has any friend's move to show. */
    val hasFriends: Boolean,
) {
    val isEmpty: Boolean get() = days.isEmpty() && headlines.isEmpty() && prizes.isEmpty() && shelves == NewsShelves.empty

    /** The day the page opens on: today when it holds news, else the nearest day that does. */
    val openingDay: LocalDate?
        get() = days.minWithOrNull { lhs, rhs ->
            val left = abs(lhs.day.toEpochDay() - today.toEpochDay())
            val right = abs(rhs.day.toEpochDay() - today.toEpochDay())
            if (left == right) rhs.day.compareTo(lhs.day) else left.compareTo(right)
        }?.day

    /** The agenda alone, cut to the `cards` nearest the opening day, for short-agenda previews. */
    fun agendaOnly(cards: Int): NewsAgenda {
        val opening = openingDay ?: today
        val kept = days.flatMap { day -> day.cards.map { day.day to it } }
            .sortedBy { abs(it.first.toEpochDay() - opening.toEpochDay()) }
            .take(cards)
        val short = kept.groupBy({ it.first }, { it.second }).map { NewsAgendaDay(it.key, it.value) }.sortedBy { it.day }
        return NewsAgenda(short, today, emptyList(), emptyList(), hasFriends = true)
    }

    companion object {
        /** How far back the headlines reach. */
        const val HEADLINE_PAST_DAYS = 20L

        /** How far ahead the headlines reach. */
        const val HEADLINE_FUTURE_DAYS = 30L

        /** How far back the agenda reaches. Ahead it has no end. */
        const val PAST_DAYS = 30L

        fun empty(now: Instant = Instant.now()) = of(emptyList(), emptyList(), emptyList(), suggestions = emptyList(), awards = emptyList(), now = now)

        private fun dayOf(instant: Instant): LocalDate = instant.atZone(ZoneId.systemDefault()).toLocalDate()

        /**
         * @param upcoming what is announced for a day, the strip's days to come.
         * @param announced everything announced, dated or not, for the shelves; `upcoming` when null.
         * @param wishlist the wish list rail, in the server's order.
         * @param dismissed cards turned down this session, gone at once.
         */
        fun of(
            released: List<ReleasedItem>,
            events: List<FeedEvent>,
            upcoming: List<UpcomingRelease>,
            announced: List<UpcomingRelease>? = null,
            wishlist: List<UpcomingRelease> = emptyList(),
            suggestions: List<Suggestion>,
            awards: List<AwardSection>,
            dismissed: Set<String> = emptySet(),
            now: Instant = Instant.now(),
        ): NewsAgenda {
            val today = dayOf(now)
            val since = today.minusDays(PAST_DAYS)
            val moves = NewsFeedLayout.friendSections(events, now = now).flatMap { it.moves }
            val byDay = linkedMapOf<LocalDate, MutableList<NewsCard>>()
            // A day's news newest first: the friends' moves and the releases.
            (moves.map(NewsCard::Friend) + released.map(NewsCard::Released))
                .mapNotNull { card ->
                    val date = card.date ?: return@mapNotNull null
                    val day = dayOf(date)
                    if (day < since || day > today) null else Triple(day, date, card)
                }
                .sortedByDescending { it.second }
                .forEach { (day, _, card) -> byDay.getOrPut(day) { mutableListOf() } += card }
            // What is announced for an exact day after today.
            val ahead = linkedMapOf<LocalDate, MutableList<NewsCard>>()
            for (release in upcoming) {
                val day = exactDay(release.date) ?: continue
                if (day > today) ahead.getOrPut(day) { mutableListOf() } += NewsCard.Upcoming(release)
            }
            // The month's discovery closes today: it has no day, and today is when it is read.
            val picks = suggestions.map(NewsCard::Discovery).filter { it.key !in dismissed }
            byDay[today] = ((byDay[today] ?: mutableListOf()) + picks.take(1)).toMutableList()

            val past = byDay.filter { it.value.isNotEmpty() }.map { NewsAgendaDay(it.key, it.value) }
            val future = ahead.map { NewsAgendaDay(it.key, it.value) }
            val year = today.year
            return NewsAgenda(
                days = (past + future).sortedBy { it.day },
                today = today,
                headlines = headlines(released, moves, upcoming, today),
                prizes = NewsDiscoverPicks.winners(awards)
                    .filter { it.mentions.firstOrNull()?.year == year }
                    .map(NewsCard::Award)
                    .filter { it.key !in dismissed },
                shelves = NewsShelves.of(released, moves, announced ?: upcoming, wishlist, today),
                hasFriends = moves.isNotEmpty(),
            )
        }

        /** The friends' coups de cœur and the releases out lately, then the releases due soon. */
        fun headlines(released: List<ReleasedItem>, moves: List<FriendMove>, upcoming: List<UpcomingRelease>, today: LocalDate): List<NewsShelfItem> {
            val since = today.minusDays(HEADLINE_PAST_DAYS)
            val until = today.plusDays(HEADLINE_FUTURE_DAYS)
            val past = (moves.filter { it.lead.kind == FeedEventKind.LOVED }.map(NewsCard::Friend) + released.map(NewsCard::Released))
                .mapNotNull { card ->
                    val date = card.date ?: return@mapNotNull null
                    if (dayOf(date) >= since) date to card else null
                }
                .sortedByDescending { it.first }
                .map { it.second }
            val coming = upcoming
                .mapNotNull { release ->
                    val day = exactDay(release.date) ?: return@mapNotNull null
                    if (day > today && day <= until) day to NewsCard.Upcoming(release) else null
                }
                .sortedWith(compareBy<Pair<LocalDate, NewsCard>> { it.first }.thenBy { it.second.id })
                .map { it.second }
            val seen = mutableSetOf<String>()
            return (past + coming).filter { seen.add(it.key) }.map { NewsShelves.item(it) }
        }

        /** The day of a `YYYY-MM-DD` date; null for a month or a year alone. */
        fun exactDay(date: String?): LocalDate? {
            val parts = date?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
            if (parts.size != 3) return null
            return runCatching { LocalDate.of(parts[0], parts[1], parts[2]) }.getOrNull()
        }
    }
}

/** The prizes in the order the page shows them. */
object NewsDiscoverPicks {
    /** The winners of every list, the latest prize first, each novel once. */
    fun winners(sections: List<AwardSection>): List<AwardWinner> {
        val seen = mutableSetOf<String>()
        return sections.flatMap { it.winners }
            .sortedByDescending { it.mentions.firstOrNull()?.year ?: 0 }
            .filter { seen.add(it.id) }
    }
}

/**
 * What the reader made of the cards' buttons on this visit: the books just wished for, by
 * `NewsCard.key`, the awaited editions of the wish list's rail just taken off it, the books just
 * taken, what each card's "+ Ajouter" did, and the cards turned down.
 */
data class NewsWishes(
    private val added: Set<String> = emptySet(),
    private val dropped: Set<String> = emptySet(),
    private val taken: Set<String> = emptySet(),
    private val done: Map<String, TakenState> = emptyMap(),
    /** Cards turned down from their eye this visit: black and white, until the reader comes back. */
    val turnedDown: Set<String> = emptySet(),
) {
    operator fun contains(key: String): Boolean = key in added

    /** A large card's state: wished here, or awaited already and not taken off. */
    fun isWished(item: NewsShelfItem): Boolean {
        val key = item.card.key
        return key in added || (item.isAwaited && key !in dropped)
    }

    /** A large card's book held already, or just taken from elsewhere on the page. */
    fun isOwned(card: NewsCard): Boolean = card.inLibrary || card.key in taken

    /** What a card's "+ Ajouter" says: the action made here, else on the wish list, else held. */
    fun state(card: NewsCard, isWished: Boolean): TakenState? {
        done[card.key]?.let { return it }
        if (isWished) return TakenState.Wished
        return if (isOwned(card)) TakenState.Owned else null
    }

    fun isTurnedDown(card: NewsCard): Boolean = card.key in turnedDown

    fun take(key: String) = copy(taken = taken + key)
    fun insert(key: String) = copy(added = added + key, dropped = dropped - key)
    fun remove(key: String) = copy(added = added - key)
    fun drop(key: String) = copy(dropped = dropped + key)
    fun restore(key: String) = copy(dropped = dropped - key)
    fun did(state: TakenState?, key: String) = copy(done = if (state == null) done - key else done + (key to state))
    fun turnDown(key: String) = copy(turnedDown = turnedDown + key)
    fun reconsider(key: String) = copy(turnedDown = turnedDown - key)
    fun forgetTurnedDown() = copy(turnedDown = emptySet())
}
