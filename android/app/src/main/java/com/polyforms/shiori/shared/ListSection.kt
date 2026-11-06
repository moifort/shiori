package com.polyforms.shiori.shared

import com.polyforms.shiori.shared.components.atoms.starsText
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.time.temporal.TemporalAdjusters
import java.util.Locale

/** A titled run of rows, cut from a list the server already ordered. */
data class ListSection<Row>(val id: String, val title: String, val rows: List<Row>) {
    companion object {
        fun <Row> byMonth(rows: List<Row>, date: (Row) -> Instant?): List<ListSection<Row>> =
            MonthSection.cut(rows, date).map { ListSection(it.id, it.title, it.rows) }

        /** Today, yesterday, this week, last week, earlier this month, then month by month. */
        fun <Row> byPeriod(rows: List<Row>, date: (Row) -> Instant?, now: Instant = Instant.now()): List<ListSection<Row>> {
            val sections = mutableListOf<ListSection<Row>>()
            var current: JournalPeriod? = null
            var started = false
            val runs = mutableMapOf<String, Int>()
            for (row in rows) {
                val period = date(row)?.let { JournalPeriod.of(it, now) }
                if (started && period == current) {
                    val last = sections.last()
                    sections[sections.lastIndex] = last.copy(rows = last.rows + row)
                    continue
                }
                started = true
                current = period
                val title = period?.title(now) ?: L("Sans date")
                val run = runs[title] ?: 0
                runs[title] = run + 1
                sections += ListSection("$title#$run", title, listOf(row))
            }
            return sections
        }

        fun <Row> byYear(rows: List<Row>, date: (Row) -> Instant?): List<ListSection<Row>> {
            val sections = mutableListOf<ListSection<Row>>()
            for (row in rows) {
                val title = date(row)?.let { DateText.local(it).year.toString() } ?: L("Sans date")
                val last = sections.lastOrNull()
                if (last != null && last.title == title) {
                    sections[sections.lastIndex] = last.copy(rows = last.rows + row)
                } else {
                    sections += ListSection("$title#${sections.size}", title, listOf(row))
                }
            }
            return sections
        }

        fun <Row> byRank(rows: List<Row>, rank: (Row) -> LovedRank?): List<ListSection<Row>> {
            val sections = mutableListOf<Pair<LovedRank?, ListSection<Row>>>()
            val runs = mutableMapOf<LovedRank?, Int>()
            for (row in rows) {
                val current = rank(row)
                val last = sections.lastOrNull()
                if (last != null && last.first == current) {
                    sections[sections.lastIndex] = current to last.second.copy(rows = last.second.rows + row)
                } else {
                    val run = runs[current] ?: 0
                    runs[current] = run + 1
                    val id = "${current?.order ?: "none"}#$run"
                    sections += current to ListSection(id, current?.title ?: L("Sans note"), listOf(row))
                }
            }
            return sections.map { it.second }
        }
    }
}

/** Where a journal entry falls, as the Library's recent shelf groups them. */
sealed interface JournalPeriod {
    data object Today : JournalPeriod
    data object Yesterday : JournalPeriod
    data object ThisWeek : JournalPeriod
    data object LastWeek : JournalPeriod
    data object EarlierThisMonth : JournalPeriod
    data class Month(val month: ShelfMonth) : JournalPeriod

    fun title(now: Instant): String {
        val today = DateText.local(now)
        val locale = Locale.getDefault()
        return when (this) {
            Today -> L("Aujourd'hui")
            Yesterday -> L("Hier")
            ThisWeek -> L("Cette semaine")
            LastWeek -> L("La semaine dernière")
            EarlierThisMonth -> L("Plus tôt en %@", today.month.getDisplayName(TextStyle.FULL, locale))
            is Month -> {
                val date = LocalDate.of(month.year, month.month, 1)
                val name = if (month.year == today.year) date.month.getDisplayName(TextStyle.FULL, locale) else DateText.monthLongYear(date)
                name.replaceFirstChar { it.titlecase(locale) }
            }
        }
    }

    companion object {
        fun of(instant: Instant, now: Instant): JournalPeriod {
            val zone = ZoneId.systemDefault()
            val day = instant.atZone(zone).toLocalDate()
            val today = now.atZone(zone).toLocalDate()
            val firstDay = java.time.temporal.WeekFields.of(Locale.getDefault()).firstDayOfWeek
            val week = today.with(TemporalAdjusters.previousOrSame(firstDay ?: DayOfWeek.MONDAY))
            val lastWeek = week.minusWeeks(1)
            val month = today.withDayOfMonth(1)
            return when {
                !day.isBefore(today) -> Today
                day.plusDays(1) == today -> Yesterday
                !day.isBefore(week) -> ThisWeek
                !day.isBefore(lastWeek) -> LastWeek
                !day.isBefore(month) -> EarlierThisMonth
                else -> Month(ShelfMonth(day.year, day.monthValue))
            }
        }
    }
}

/** How much the reader loves something: a heart, or a number of stars. */
sealed interface LovedRank {
    data object Hearts : LovedRank
    data class Stars(val count: Double) : LovedRank

    val order: Int get() = when (this) {
        Hearts -> 0
        is Stars -> ((6 - count) * 2).toInt()
    }

    val title: String get() = when (this) {
        Hearts -> L("Coups de cœur")
        is Stars -> when {
            count == 1.0 -> L("1 étoile")
            count == Math.rint(count) -> L("%lld étoiles", count.toInt())
            else -> L("%@ étoiles", count.starsText)
        }
    }

    companion object {
        fun of(favorite: Boolean, rating: Double?, lentRating: Double? = null): LovedRank? = when {
            favorite || (rating == null && lentRating == 5.0) -> Hearts
            (rating ?: lentRating) != null -> Stars(rating ?: lentRating!!)
            else -> null
        }
    }
}

val Book.lovedRank: LovedRank? get() = LovedRank.of(favorite, rating, if (status == ReadingStatus.READ) seriesRating else null)
val FollowedSeries.lovedRank: LovedRank? get() = LovedRank.of(opinion?.favorite == true, opinion?.rating)
