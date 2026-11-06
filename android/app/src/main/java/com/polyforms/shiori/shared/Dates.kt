package com.polyforms.shiori.shared

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

object InstantSerializer : KSerializer<Instant> {
    override val descriptor = PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: Instant) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): Instant = Instant.parse(decoder.decodeString())
}

/** A GraphQL `DateTime` read as an instant. Nil on anything that is not one. */
fun parseISO8601(value: String?): Instant? = value?.let { runCatching { Instant.parse(it) }.getOrNull() }

/** An instant written as the server writes them. */
fun iso8601(instant: Instant): String = DateTimeFormatter.ISO_INSTANT.format(instant.truncatedTo(ChronoUnit.MILLIS))

private val locale: Locale get() = Locale.getDefault()

/** `Date.formatted(.dateTime.day().month(.abbreviated))` and its neighbours. */
object DateText {
    fun dayMonthShort(date: LocalDate): String =
        "${date.dayOfMonth} ${date.month.getDisplayName(TextStyle.SHORT, locale)}"

    fun dayMonthShortYear(date: LocalDate): String = "${dayMonthShort(date)} ${date.year}"

    fun dayMonthLongYear(date: LocalDate): String =
        "${date.dayOfMonth} ${date.month.getDisplayName(TextStyle.FULL, locale)} ${date.year}"

    fun monthShortYear(date: LocalDate): String =
        "${date.month.getDisplayName(TextStyle.SHORT, locale)} ${date.year}"

    fun monthLongYear(date: LocalDate): String =
        "${date.month.getDisplayName(TextStyle.FULL, locale)} ${date.year}"

    fun local(instant: Instant): LocalDate = instant.atZone(ZoneId.systemDefault()).toLocalDate()
}

/** A release date in words, as precisely as it was announced: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`. */
object ReleaseDateText {
    fun lastDay(date: String): String = when (date.length) {
        10 -> date
        7 -> "$date-31"
        else -> "$date-12-31"
    }

    /** Still to come: a day after today, or a month or a year not over yet. */
    fun isUpcoming(date: String, today: LocalDate = LocalDate.now()): Boolean {
        val day = today.toString()
        return if (date.length == 10) date > day else lastDay(date) >= day
    }

    private fun parts(date: String): Pair<LocalDate, Int>? {
        val parts = date.split("-").mapNotNull { it.toIntOrNull() }
        val year = parts.firstOrNull() ?: return null
        return runCatching {
            LocalDate.of(year, parts.getOrElse(1) { 1 }, parts.getOrElse(2) { 1 }) to parts.size
        }.getOrNull()
    }

    /** Under a cover: "8 oct.", "oct. 2026", "2027". */
    fun short(date: String): String {
        val (day, precision) = parts(date) ?: return date
        return when (precision) {
            3 -> DateText.dayMonthShort(day)
            2 -> DateText.monthShortYear(day)
            else -> date.take(4)
        }
    }

    /** In a fact tile: "12 janv. 2027", "mars 2027", "2027". */
    fun full(date: String): String {
        val (day, precision) = parts(date) ?: return date
        return when (precision) {
            3 -> DateText.dayMonthShortYear(day)
            2 -> DateText.monthLongYear(day)
            else -> date.take(4)
        }
    }

    /** In a sentence: "le 19 févr. 2027", "en mars 2027", "en 2027". */
    fun phrase(date: String): String {
        val (day, precision) = parts(date) ?: return date
        return when (precision) {
            3 -> L("le %@", DateText.dayMonthShortYear(day))
            2 -> L("en %@", DateText.monthLongYear(day))
            else -> L("en %@", date.take(4))
        }
    }

    /** How long until it comes out: "10 jours", "2 mois", "1 an". */
    fun countdown(date: String, today: LocalDate = LocalDate.now()): String? {
        val (day, precision) = parts(date) ?: return null
        if (precision <= 1) return null
        val days = ChronoUnit.DAYS.between(today, day)
        if (days <= 0) return null
        val fr = Strings.appLanguage == "fr"
        if (days < 30) return if (fr) "$days ${if (days > 1) "jours" else "jour"}" else "$days ${if (days > 1) "days" else "day"}"
        val years = ChronoUnit.YEARS.between(today, day)
        if (years > 0) return if (fr) "$years ${if (years > 1) "ans" else "an"}" else "$years ${if (years > 1) "years" else "year"}"
        val months = maxOf(ChronoUnit.MONTHS.between(today, day), 1)
        return if (fr) "$months mois" else "$months ${if (months > 1) "months" else "month"}"
    }

    /** "Sort le 8 octobre 2026", "Sort en octobre 2026", "Sort en 2027". */
    fun coming(date: String): String {
        val (day, precision) = parts(date) ?: return date
        return when (precision) {
            3 -> L("Sort le %@", DateText.dayMonthLongYear(day))
            2 -> L("Sort en %@", DateText.monthLongYear(day))
            else -> L("Sort en %@", date.take(4))
        }
    }

    /** "Sorti le 16 septembre 2026", "Sorti en août 2026", "Sorti en 2026". */
    fun out(date: String): String {
        val (day, precision) = parts(date) ?: return date
        return when (precision) {
            3 -> L("Sorti le %@", DateText.dayMonthLongYear(day))
            2 -> L("Sorti en %@", DateText.monthLongYear(day))
            else -> L("Sorti en %@", date.take(4))
        }
    }

    /** The month names in capitals, cut to three letters (four where three collide). */
    val clippedMonths: List<String> by lazy {
        val bare = (1..12).map {
            java.time.Month.of(it).getDisplayName(TextStyle.SHORT, locale).replace(".", "").uppercase(locale)
        }
        val three = bare.map { it.take(3) }
        bare.indices.map { i -> if (three.count { it == three[i] } > 1) bare[i].take(4) else three[i] }
    }

    fun shortMonth(number: Int): String =
        if (number in 1..12) java.time.Month.of(number).getDisplayName(TextStyle.SHORT, locale) else ""
}

/** The month a row of the Library or Series tab is filed under: "Septembre 2026". */
data class ShelfMonth(val year: Int, val month: Int) {
    val title: String
        get() {
            val raw = DateText.monthLongYear(LocalDate.of(year, month, 1))
            return raw.replaceFirstChar { it.titlecase(locale) }
        }

    companion object {
        fun of(instant: Instant): ShelfMonth {
            val date = DateText.local(instant)
            return ShelfMonth(date.year, date.monthValue)
        }
    }
}

/** One month of rows, cut out of a list the server already ordered. */
data class MonthSection<Row>(val id: String, val month: ShelfMonth?, val rows: List<Row>) {
    val title: String get() = month?.title ?: L("Sans date")

    companion object {
        fun <Row> cut(rows: List<Row>, date: (Row) -> Instant?): List<MonthSection<Row>> {
            val sections = mutableListOf<MonthSection<Row>>()
            val runs = mutableMapOf<ShelfMonth?, Int>()
            for (row in rows) {
                val month = date(row)?.let { ShelfMonth.of(it) }
                val last = sections.lastOrNull()
                if (last != null && last.month == month) {
                    sections[sections.size - 1] = last.copy(rows = last.rows + row)
                } else {
                    val run = runs[month] ?: 0
                    runs[month] = run + 1
                    val name = month?.let { "${it.year}-${it.month}" } ?: "undated"
                    sections += MonthSection("$name#$run", month, listOf(row))
                }
            }
            return sections
        }
    }
}
