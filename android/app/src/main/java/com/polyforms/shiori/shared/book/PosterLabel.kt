package com.polyforms.shiori.shared.book

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SystemTint
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** What a poster cover says under it, and how it is drawn: dimmed, greyed, bookmarked. */
data class PosterLabel(
    val caption: String,
    val marksReading: Boolean = false,
    val progress: Int? = null,
    val rating: Double? = null,
    val dimming: Double = 0.12,
    val isGreyed: Boolean = false,
) {
    enum class Context { RECENT, JOURNAL, PILE, READ, LOVED_BY_YEAR, LOVED_BY_AUTHOR, DROPPED }

    /** How long ago, cut as the labels say it. */
    sealed interface Span {
        data object Today : Span
        data object Yesterday : Span
        data class Days(val n: Int) : Span
        data class Weeks(val n: Int) : Span
        data class Months(val n: Int) : Span
        data class Years(val n: Int) : Span

        companion object {
            fun of(date: Instant, now: Instant): Span {
                val start = date.atZone(ZoneId.systemDefault()).toLocalDate()
                val end = now.atZone(ZoneId.systemDefault()).toLocalDate()
                val days = maxOf(0L, ChronoUnit.DAYS.between(start, end)).toInt()
                val months = ChronoUnit.MONTHS.between(start, end).toInt()
                val years = ChronoUnit.YEARS.between(start, end).toInt()
                return when {
                    days == 0 -> Today
                    days == 1 -> Yesterday
                    days < 14 -> Days(days)
                    months < 1 && years < 1 -> Weeks(days / 7)
                    years > 0 -> Years(years)
                    else -> Months(maxOf(1, months))
                }
            }
        }
    }

    companion object {
        const val SET_ASIDE_DIMMING = 0.5

        fun of(book: Book, context: Context, now: Instant = Instant.now()): PosterLabel {
            val since = book.shelvedAt ?: book.statusChangedAt
            return when (context) {
                Context.PILE -> PosterLabel(since?.let { waited(it, now) } ?: "")
                Context.LOVED_BY_YEAR ->
                    if (since != null && book.status == ReadingStatus.READ) {
                        PosterLabel(L("Lu en %@", DateText.local(since).year.toString()))
                    } else {
                        PosterLabel(book.authorLine)
                    }
                Context.LOVED_BY_AUTHOR -> PosterLabel(book.authors.joinToString(" · "))
                Context.DROPPED -> PosterLabel(
                    (book.statusChangedAt ?: book.shelvedAt)?.let { waited(it, now) } ?: "",
                    progress = book.listeningProgress,
                    dimming = SET_ASIDE_DIMMING,
                    isGreyed = true,
                )
                Context.READ -> readLabel(book, now)
                Context.RECENT, Context.JOURNAL -> movedLabel(book, context == Context.JOURNAL, since, now)
            }
        }

        private fun movedLabel(book: Book, journal: Boolean, since: Instant?, now: Instant): PosterLabel = when (book.status) {
            ReadingStatus.TO_READ ->
                if (journal || since == null) PosterLabel(L("Ajouté")) else PosterLabel(added(since, now))
            ReadingStatus.READING -> {
                val progress = book.listeningProgress
                when {
                    progress != null -> PosterLabel("$progress%", marksReading = true, progress = progress)
                    journal || since == null -> PosterLabel(L("Commencé"), marksReading = true)
                    else -> PosterLabel(open(since, now), marksReading = true)
                }
            }
            ReadingStatus.READ -> readLabel(book, now)
            ReadingStatus.DROPPED -> PosterLabel(L("Abandonné"), progress = book.listeningProgress, dimming = SET_ASIDE_DIMMING, isGreyed = true)
        }

        private fun readLabel(book: Book, now: Instant): PosterLabel {
            if (book.favorite) return PosterLabel(stars(5.0), rating = 5.0)
            book.shownRating?.let { return PosterLabel(stars(it), rating = it) }
            val date = book.shelvedAt ?: return PosterLabel(L("Lu"))
            val day = DateText.local(date)
            val today = DateText.local(now)
            if (day == today) return PosterLabel(L("Lu aujourd'hui"))
            if (day == today.minusDays(1)) return PosterLabel(L("Lu hier"))
            return PosterLabel(L("Lu le %@", DateText.dayMonthShort(day)))
        }

        fun stars(rating: Double): String {
            val whole = rating.toInt()
            val half = rating - whole >= 0.5
            return "★".repeat(whole.coerceIn(0, 5)) + if (half) "½" else ""
        }

        fun waited(date: Instant, now: Instant): String = when (val span = Span.of(date, now)) {
            Span.Today -> L("Aujourd'hui")
            Span.Yesterday -> L("Hier")
            is Span.Days -> L("%lld jours", span.n)
            is Span.Weeks -> L("%lld sem.", span.n)
            is Span.Months -> L("%lld mois", span.n)
            is Span.Years -> if (span.n == 1) L("1 an") else L("%lld ans", span.n)
        }

        fun added(date: Instant, now: Instant): String = when (val span = Span.of(date, now)) {
            Span.Today -> L("Ajouté")
            Span.Yesterday -> L("Ajouté hier")
            is Span.Days -> L("Il y a %lldj", span.n)
            is Span.Weeks -> L("Il y a %lld sem.", span.n)
            is Span.Months -> L("Il y a %lld mois", span.n)
            is Span.Years -> if (span.n == 1) L("Il y a 1 an") else L("Il y a %lld ans", span.n)
        }

        fun open(date: Instant, now: Instant): String = when (val span = Span.of(date, now)) {
            Span.Today -> L("Commencé")
            Span.Yesterday -> L("depuis hier")
            is Span.Days -> L("depuis %lldj", span.n)
            is Span.Weeks -> L("depuis %lld sem.", span.n)
            is Span.Months -> L("depuis %lld mois", span.n)
            is Span.Years -> if (span.n == 1) L("depuis 1 an") else L("depuis %lld ans", span.n)
        }

        fun toReadSince(date: Instant, now: Instant): String = when (val span = Span.of(date, now)) {
            Span.Today -> L("ajouté aujourd'hui")
            Span.Yesterday -> L("à lire depuis hier")
            is Span.Days -> L("à lire depuis %lldj", span.n)
            is Span.Weeks -> L("à lire depuis %lld sem.", span.n)
            is Span.Months -> L("à lire depuis %lld mois", span.n)
            is Span.Years -> if (span.n == 1) L("à lire depuis 1 an") else L("à lire depuis %lld ans", span.n)
        }

        fun readOn(date: Instant, now: Instant): String {
            if (Span.of(date, now) is Span.Years) return L("lu en %@", DateText.local(date).year.toString())
            return L("lu le %@", DateText.dayMonthShort(DateText.local(date)))
        }
    }
}

/** Where the reader stands with a book, as its hero says it: "à lire depuis 3 sem.". */
fun BookState.Companion.reading(book: Book, now: Instant = Instant.now()): BookState {
    val tint = when (book.status) {
        ReadingStatus.TO_READ -> SystemTint.ORANGE
        ReadingStatus.READING -> SystemTint.BLUE
        ReadingStatus.READ -> SystemTint.GREEN
        ReadingStatus.DROPPED -> SystemTint.RED
    }
    val plain = BookState(book.status.label.lowercase(), tint)
    return when (book.status) {
        ReadingStatus.TO_READ -> {
            if (book.forthcoming) return forthcoming
            val added = book.addedAt ?: return plain
            BookState(PosterLabel.toReadSince(added, now), tint)
        }
        ReadingStatus.READING -> {
            val started = book.startedAt ?: return plain
            val opened = if (DateText.local(started) == LocalDate.now()) L("commencé aujourd'hui") else PosterLabel.open(started, now)
            BookState(opened, tint)
        }
        ReadingStatus.READ -> {
            val finished = book.finishedAt ?: return plain
            BookState(PosterLabel.readOn(finished, now), tint)
        }
        ReadingStatus.DROPPED -> plain
    }
}

/** An author or a narrator a line opens. */
data class PersonDestination(val key: String, val name: String)

val Book.authorDestinations: List<PersonDestination>
    get() {
        val keys = authorKeys ?: return emptyList()
        if (keys.size != authors.size) return emptyList()
        return keys.zip(authors).map { PersonDestination(it.first, it.second) }
    }

val Book.narratorDestinations: List<PersonDestination>
    get() {
        val keys = narratorKeys ?: return emptyList()
        if (keys.size != narrators.size) return emptyList()
        return keys.zip(narrators).map { PersonDestination(it.first, it.second) }
    }
