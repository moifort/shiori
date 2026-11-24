package com.polyforms.shiori.features.news

import android.icu.text.RelativeDateTimeFormatter
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.narrators.NarratorDestination
import com.polyforms.shiori.features.news.components.pages.NewsCardText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * One cover of a Découvrir shelf: the book, the short line in its foot, and the person whose news
 * it is — a friend, an author, a narrator — in a pill on its top corner.
 */
data class NewsShelfItem(
    val card: NewsCard,
    /** "Tome 9 · 14 nov.", "Sorti · 12 oct.", "Annoncé · mars", "Il y a 3 jours". */
    val caption: String,
    /** The friend, the author or the narrator the pill names. */
    val person: String? = null,
    val portraitURL: String? = null,
    /** The friend's move: the pill then shows their face and names them by their first name. */
    val friend: FeedEvent? = null,
    /** A friend's stars, drawn in place of the line. */
    val rating: Double? = null,
    /** Where a wish list edition out stands, "Sorti · 6 nov." or "Disponible". */
    val standing: String? = null,
) {
    val id: String get() = card.id

    /** The name in the pill: a friend's first name, "M. Wells" for an author. */
    val pillName: String? get() = person?.let { if (friend == null) NewsShelves.shortName(it) else it }

    val avatar: AccountAvatar? get() = friend?.avatar

    /** Where the pill leads: the Amis tab narrowed to the friend, the author's page, the narrator's. */
    val personTarget: NewsPersonTarget?
        get() {
            friend?.let { return NewsPersonTarget.Friend(it.friendId) }
            val card = card
            val release = when (card) {
                is NewsCard.Released -> when (val item = card.item) {
                    is ReleasedItem.Narrator -> return NewsPersonTarget.Narrator(NarratorDestination(item.news.narratorKey, item.news.narrator))
                    is ReleasedItem.Release -> item.release
                }
                is NewsCard.Upcoming -> card.release
                else -> return null
            }
            return when (val destination = UpcomingReleaseDestination.immediate(release)) {
                is UpcomingReleaseDestination.Author -> NewsPersonTarget.Author(destination.author)
                is UpcomingReleaseDestination.Narrator -> NewsPersonTarget.Narrator(destination.narrator)
                else -> null
            }
        }

    /**
     * A large card's word on the foot of its cover: what happened, without the day the date leaf
     * says — "♥ Adoré", "Tome 9", "Sorti", "Annoncé", "À paraître".
     */
    val word: String
        get() {
            standing?.let { return it }
            return when (val card = card) {
                is NewsCard.Friend -> NewsShelves.action(card.move.lead)
                is NewsCard.Released -> when (val item = card.item) {
                    is ReleasedItem.Release -> if (item.release.source == ReleaseSource.SAGA && item.release.volume != null) L("Tome %lld", item.release.volume) else L("Sorti")
                    is ReleasedItem.Narrator -> L("Sorti")
                }
                is NewsCard.Upcoming -> when (card.release.source) {
                    ReleaseSource.SAGA -> card.release.volume?.let { L("Tome %lld", it) } ?: L("Annoncé")
                    ReleaseSource.AWAITED -> if (card.release.date == null) L("En vue") else L("À paraître")
                    ReleaseSource.AUTHOR, ReleaseSource.NARRATOR -> L("Annoncé")
                }
                is NewsCard.Discovery, is NewsCard.Award -> caption
            }
        }

    /**
     * The card's day, as `YYYY-MM-DD` — or `YYYY-MM`, `YYYY` for what is announced that loosely:
     * the date leaf in the corner. Null for the prizes, the month's discovery and what has no date.
     */
    val day: String?
        get() {
            if (standing != null) return null
            return when (val card = card) {
                is NewsCard.Released -> card.item.day.toString()
                is NewsCard.Upcoming -> card.release.date
                is NewsCard.Friend -> card.move.lead.at.atZone(ZoneId.systemDefault()).toLocalDate().toString()
                is NewsCard.Discovery, is NewsCard.Award -> null
            }
        }

    /** An edition the reader awaits already: its card says it is in the wish list. */
    val isAwaited: Boolean get() = (card as? NewsCard.Upcoming)?.release?.source == ReleaseSource.AWAITED
}

/** The person a Découvrir card names, as its pill opens them. */
sealed interface NewsPersonTarget {
    /** The Amis tab, showing that friend alone. */
    data class Friend(val friendId: String) : NewsPersonTarget
    data class Author(val author: AuthorDestination) : NewsPersonTarget
    data class Narrator(val narrator: NarratorDestination) : NewsPersonTarget
}

/**
 * The shelves under Découvrir's agenda, each a rail of what one of the reader's follows brought:
 * what each friend did last, the friends' favourites, the followed series, the favourite authors
 * and narrators, the wish list. Pure: built from the same loads as the agenda.
 */
data class NewsShelves(
    /** Each friend's latest move, however old, the most recent friend first. */
    val activity: List<NewsShelfItem>,
    /** The friends' coups de cœur, newest first, each book once, how long ago in the foot. */
    val loves: List<NewsShelfItem>,
    /** One card per followed series: its volume out lately, else its next. */
    val series: List<NewsShelfItem>,
    /** The new books of the authors the reader hearted, out or announced. */
    val authors: List<NewsShelfItem>,
    /** The new recordings of the narrators the reader follows. */
    val narrators: List<NewsShelfItem>,
    /** The editions the reader awaits, in the server's order. */
    val wishes: List<NewsShelfItem>,
) {
    companion object {
        /** How many covers a shelf shows at most. */
        const val LIMIT = 10

        val empty = NewsShelves(emptyList(), emptyList(), emptyList(), emptyList(), emptyList(), emptyList())

        /**
         * @param released what came out lately, newest first.
         * @param moves the friends' moves, newest first.
         * @param upcoming everything announced, dated or not.
         * @param wishlist the editions awaited the wish list rail shows, in the server's order.
         */
        fun of(released: List<ReleasedItem>, moves: List<FriendMove>, upcoming: List<UpcomingRelease>, wishlist: List<UpcomingRelease> = emptyList(), today: LocalDate): NewsShelves {
            val sorted = moves.sortedByDescending { it.lead.at }
            val seenFriends = mutableSetOf<String>()
            val activity = sorted.filter { seenFriends.add(it.lead.friendId) }.take(LIMIT).map { friendItem(it, action(it.lead)) }
            val seenBooks = mutableSetOf<String>()
            val loves = sorted.filter { it.lead.kind == FeedEventKind.LOVED && seenBooks.add(it.lead.bookId) }
                .take(LIMIT)
                .map { friendItem(it, relative(it.lead.at, today), showsStars = false) }
            val out = released.sortedByDescending { it.day }
            // What is still to come, soonest first: a month or a year alone may still be ahead.
            val ahead = upcoming.filter { release -> NewsAgenda.exactDay(release.date)?.let { it > today } ?: true }
                .sortedBy { it.date ?: "9999" }
            fun outRelease(source: ReleaseSource) = out.mapNotNull { (it as? ReleasedItem.Release)?.takeIf { r -> r.release.source == source } }
            fun aheadRelease(source: ReleaseSource) = ahead.filter { it.source == source }

            // Series: one card each, the volume out lately before the next to come.
            val seenSeries = mutableSetOf<String>()
            val seriesItems = mutableListOf<NewsShelfItem>()
            for (item in outRelease(ReleaseSource.SAGA)) {
                if (seenSeries.add(item.release.seriesName ?: item.release.id)) {
                    seriesItems += NewsShelfItem(NewsCard.Released(item), volumeTag(item.release, L("sorti")))
                }
            }
            for (release in aheadRelease(ReleaseSource.SAGA)) {
                if (seenSeries.add(release.seriesName ?: release.id)) {
                    seriesItems += NewsShelfItem(NewsCard.Upcoming(release), volumeTag(release, release.date?.let(::shortDate) ?: L("annoncé")))
                }
            }

            // Favourite authors: what they brought out lately, then what they announced.
            fun favourite(release: UpcomingRelease) = release.author?.favorite == true
            val authorItems = outRelease(ReleaseSource.AUTHOR).filter { favourite(it.release) }.map {
                NewsShelfItem(NewsCard.Released(it), outCaption(it.day), it.release.author?.name ?: it.release.authors.firstOrNull(), it.release.author?.portraitURL)
            } + aheadRelease(ReleaseSource.AUTHOR).filter(::favourite).map {
                NewsShelfItem(NewsCard.Upcoming(it), announcedCaption(it.date), it.author?.name ?: it.authors.firstOrNull(), it.author?.portraitURL)
            }

            // Narrators: their recordings out lately, then the ones announced.
            val narratorItems = mutableListOf<NewsShelfItem>()
            for (item in out) {
                when (item) {
                    is ReleasedItem.Narrator -> narratorItems += NewsShelfItem(NewsCard.Released(item), outCaption(item.day), item.news.narrator)
                    is ReleasedItem.Release -> if (item.release.source == ReleaseSource.NARRATOR) {
                        narratorItems += NewsShelfItem(NewsCard.Released(item), outCaption(item.day), item.release.narrator)
                    }
                }
            }
            narratorItems += aheadRelease(ReleaseSource.NARRATOR).map { NewsShelfItem(NewsCard.Upcoming(it), announcedCaption(it.date), it.narrator) }

            // The wish list, as the server orders it.
            val wishes = wishlist.take(LIMIT).map { release ->
                val (caption, isOut) = wishCaption(release, today)
                NewsShelfItem(NewsCard.Upcoming(release), caption, standing = if (isOut) caption else null)
            }
            return NewsShelves(activity, loves, seriesItems.take(LIMIT), authorItems.take(LIMIT), narratorItems.take(LIMIT), wishes)
        }

        /** "Tome 9 · 14 nov.", or the state alone outside a numbered series. */
        fun volumeTag(release: UpcomingRelease, state: String): String =
            release.volume?.let { L("Tome %lld · %@", it, state) } ?: state.replaceFirstChar { it.titlecase(Locale.getDefault()) }

        /**
         * A wish list edition's foot, and whether it is out: its date while to come, "Sorti · 6
         * nov." when out within the rail's thirty days, "Disponible" when it was out already.
         */
        fun wishCaption(release: UpcomingRelease, today: LocalDate): Pair<String, Boolean> {
            val available = L("Disponible") to true
            val date = release.date ?: return available
            val parts = date.split("-").mapNotNull { it.toIntOrNull() }
            val first = if (parts.size > 1) runCatching { LocalDate.of(parts[0], parts[1], parts.getOrElse(2) { 1 }) }.getOrNull() else null
            first ?: return shortDate(date) to false
            val end = if (parts.size > 2) first else first.plusMonths(1)
            if (end > today) return shortDate(date) to false
            val since = today.minusDays(NewsFeedLayout.RELEASED_DAYS)
            return if (first >= since) outCaption(first) to true else available
        }

        /** "Sorti · 12 oct." */
        fun outCaption(day: LocalDate): String = L("Sorti · %@", dayMonth(day))

        /** A friend's move as a cover: their face and first name in the pill. */
        fun friendItem(move: FriendMove, caption: String, showsStars: Boolean = true): NewsShelfItem {
            val event = move.lead
            val stars = if (showsStars && event.kind == FeedEventKind.FINISHED) event.rating?.takeIf { it > 0 } else null
            return NewsShelfItem(NewsCard.Friend(move), caption, event.friendName, friend = event, rating = stars)
        }

        /** What a friend did, in the cover's foot: "♥ Adoré", "Commencé", "Terminé". */
        fun action(event: FeedEvent): String = when (event.kind) {
            FeedEventKind.LOVED -> "♥︎ " + L("Adoré")
            FeedEventKind.STARTED -> L("Commencé")
            FeedEventKind.FINISHED -> L("Terminé")
        }

        /** How long ago: "Aujourd'hui", "Hier", "Il y a 3 jours", "Il y a 2 semaines", "Il y a 1 an". */
        fun relative(date: Instant, today: LocalDate): String {
            val days = ChronoUnit.DAYS.between(date.atZone(ZoneId.systemDefault()).toLocalDate(), today)
            if (days <= 0) return L("Aujourd'hui")
            // Null under the JVM's unit tests, where android.icu is a stub.
            val formatter: RelativeDateTimeFormatter? = RelativeDateTimeFormatter.getInstance(Locale.getDefault())
            val (count, unit) = when {
                days < 7 -> days to RelativeDateTimeFormatter.RelativeUnit.DAYS
                days < 30 -> days / 7 to RelativeDateTimeFormatter.RelativeUnit.WEEKS
                days < 365 -> days / 30 to RelativeDateTimeFormatter.RelativeUnit.MONTHS
                else -> days / 365 to RelativeDateTimeFormatter.RelativeUnit.YEARS
            }
            val text = when {
                formatter == null -> L("Il y a %lld jours", days)
                // "Hier" by name; past it, a count: "Il y a 1 an", not "L'année dernière".
                days == 1L -> formatter.format(RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
                else -> formatter.format(count.toDouble(), RelativeDateTimeFormatter.Direction.LAST, unit)
            }
            return text.replaceFirstChar { it.titlecase(Locale.getDefault()) }
        }

        /** Any card of the page as a cover of a rail: the agenda's day and the headlines. */
        fun item(card: NewsCard): NewsShelfItem = when (card) {
            is NewsCard.Friend -> friendItem(card.move, action(card.move.lead))
            is NewsCard.Released -> when (val item = card.item) {
                is ReleasedItem.Release -> {
                    val release = item.release
                    when (release.source) {
                        ReleaseSource.SAGA -> NewsShelfItem(card, release.volume?.let { L("Tome %lld", it) } ?: L("Sorti"))
                        ReleaseSource.AWAITED -> NewsShelfItem(card, volumeTag(release, L("sorti")))
                        ReleaseSource.AUTHOR -> NewsShelfItem(card, outCaption(item.day), release.author?.name ?: release.authors.firstOrNull(), release.author?.portraitURL)
                        ReleaseSource.NARRATOR -> NewsShelfItem(card, outCaption(item.day), release.narrator)
                    }
                }
                is ReleasedItem.Narrator -> NewsShelfItem(card, outCaption(item.day), item.news.narrator)
            }
            is NewsCard.Upcoming -> {
                val release = card.release
                when (release.source) {
                    ReleaseSource.SAGA, ReleaseSource.AWAITED -> NewsShelfItem(card, volumeTag(release, release.date?.let(::shortDate) ?: L("annoncé")))
                    ReleaseSource.AUTHOR -> NewsShelfItem(card, announcedCaption(release.date), release.author?.name ?: release.authors.firstOrNull(), release.author?.portraitURL)
                    ReleaseSource.NARRATOR -> NewsShelfItem(card, announcedCaption(release.date), release.narrator)
                }
            }
            is NewsCard.Discovery, is NewsCard.Award -> NewsShelfItem(card, NewsCardText.label(card, long = false))
        }

        /** "Annoncé · 14 nov.", "Annoncé · mars", "Annoncé". */
        fun announcedCaption(date: String?): String = date?.let { L("Annoncé · %@", shortDate(it)) } ?: L("Annoncé")

        /** "14 nov.", "mars", "2027", from `YYYY-MM-DD`, `YYYY-MM` or `YYYY`. */
        fun shortDate(date: String): String {
            val parts = date.split("-").mapNotNull { it.toIntOrNull() }
            val year = parts.firstOrNull() ?: return date
            if (parts.size < 2) return year.toString()
            val day = runCatching { LocalDate.of(year, parts[1], parts.getOrElse(2) { 1 }) }.getOrNull() ?: return year.toString()
            return if (parts.size > 2) dayMonth(day) else day.format(DateTimeFormatter.ofPattern("LLLL", Locale.getDefault()))
        }

        /** "14 nov." */
        fun dayMonth(day: LocalDate): String = day.format(DateTimeFormatter.ofPattern("d MMM", Locale.getDefault()))

        /** "Martha Wells" → "M. Wells", so the name holds in the pill; a single name stays whole. */
        fun shortName(name: String?): String {
            val words = (name ?: "").split(" ").filter { it.isNotEmpty() }
            if (words.size < 2) return name ?: ""
            return "${words.first().first()}. ${words.last()}"
        }
    }
}
