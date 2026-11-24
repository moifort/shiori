package com.polyforms.shiori.features.news

import com.polyforms.shiori.shared.L
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

/**
 * One line of the list: a day with what is out on it, or a label standing where a day cannot
 * ("2027", "Sans date"). `symbol` stands in the date column instead of the label: the binoculars
 * of the editions awaited with nothing announced.
 */
data class ReleaseDay(val id: String, val weekday: String?, val label: String, val symbol: String? = null, val releases: List<UpcomingRelease>)

/** A month of the list, its days in date order. */
data class ReleaseMonthSection(val id: String, val title: String, val days: List<ReleaseDay>)

/**
 * The upcoming releases laid on a calendar, from `now`. Pure: the same releases and the same day
 * always give the same grid.
 */
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
