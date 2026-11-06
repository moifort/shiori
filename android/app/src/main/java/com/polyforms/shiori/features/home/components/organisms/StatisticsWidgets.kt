package com.polyforms.shiori.features.home.components.organisms

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.atoms.tint
import com.polyforms.shiori.shared.components.molecules.Segment
import com.polyforms.shiori.shared.components.molecules.SegmentedBar
import com.polyforms.shiori.shared.components.molecules.WidgetCard
import com.polyforms.shiori.shared.components.molecules.WidgetEmptyMessage
import com.polyforms.shiori.shared.components.molecules.WidgetPlaceholder
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.SegmentedControl
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.color
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.features.home.daysAgo
import java.text.NumberFormat
import java.time.Month
import java.time.format.TextStyle as DateStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/** The dashboard's colours, one per measure. */
object DashboardPalette {
    val books @Composable get() = Shiori.colors.pink
    val pages @Composable get() = Shiori.colors.green
    val duration @Composable get() = Shiori.colors.cyan
    val pile @Composable get() = Shiori.colors.orange
    val others @Composable get() = Shiori.colors.gray
    val genres @Composable get() = listOf(Shiori.colors.blue, Shiori.colors.orange, Shiori.colors.teal, Shiori.colors.brown)
}

/** Read, loved, to read: three tiles, each opening its shelf. */
@Composable
fun StatTilesRow(readCount: Int, favoriteCount: Int, toReadCount: Int, onRead: () -> Unit, onFavorites: () -> Unit, onPile: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Tile(L("Lus"), readCount, ReadingStatus.READ.symbol, ReadingStatus.READ.tint, Modifier.weight(1f), onRead)
        Tile(L("Favoris"), favoriteCount, "heart.fill", Shiori.colors.red, Modifier.weight(1f), onFavorites)
        Tile(L("Pile à lire"), toReadCount, ReadingStatus.TO_READ.symbol, DashboardPalette.pile, Modifier.weight(1f), onPile)
    }
}

@Composable
private fun Tile(title: String, count: Int, symbol: String, color: Color, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.background(Shiori.colors.secondaryGroupedBackground, RoundedCornerShape(16.dp)).plainClickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Symbol(symbol), null, Modifier.size(18.dp), tint = color)
            Text(if (count > 0) NumberFormat.getIntegerInstance().format(count) else "–", style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = color, maxLines = 1)
        }
        Text(title, style = Shiori.type.caption, color = Shiori.colors.secondaryLabel, maxLines = 1)
    }
}

/** The genres read, as a bar cut in proportion. */
@Composable
fun GenresWidget(genres: List<Dashboard.GenreSlice>, onTap: (() -> Unit)?) {
    val palette = DashboardPalette.genres
    val others = DashboardPalette.others
    WidgetCard(L("Genres lus"), action = onTap) {
        if (genres.isEmpty()) {
            WidgetEmptyMessage(L("Terminez un livre pour voir vos genres."), WidgetPlaceholder.SEGMENTS)
        } else {
            SegmentedBar(genres.mapIndexed { index, slice -> Segment(slice.id, slice.genre?.label ?: L("Autres"), slice.count, if (slice.genre == null) others else palette[index % palette.size]) })
        }
    }
}

private enum class ChartMetric(val key: String) { BOOKS("books"), PAGES("pages"), HOURS("hours") }

/** Books by year, pages or hours by month, as bars; the measure is remembered. */
@Composable
fun ReadingChartWidget(
    currentYear: Int,
    booksPerYear: List<Dashboard.YearCount>,
    pagesPerMonth: List<Dashboard.MonthPages>,
    hoursPerMonth: List<Dashboard.MonthHours>,
    hasAudiobooks: Boolean,
    hasPrintedBooks: Boolean,
) {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("shiori", Context.MODE_PRIVATE) }
    val metrics = ChartMetric.entries.filter { it == ChartMetric.BOOKS || (it == ChartMetric.PAGES && hasPrintedBooks) || (it == ChartMetric.HOURS && hasAudiobooks) }
    val fallback = if (hasPrintedBooks) ChartMetric.PAGES else ChartMetric.HOURS
    var stored by remember { mutableStateOf(preferences.getString("home.chart.metric", null)) }
    val wanted = ChartMetric.entries.firstOrNull { it.key == stored } ?: fallback
    val metric = if (wanted in metrics) wanted else if (fallback in metrics) fallback else ChartMetric.BOOKS
    val number = NumberFormat.getIntegerInstance()
    val (title, color) = when (metric) {
        ChartMetric.BOOKS -> L("Livres lus") to DashboardPalette.books
        ChartMetric.PAGES -> L("Pages lues") to DashboardPalette.pages
        ChartMetric.HOURS -> L("Heures écoutées") to DashboardPalette.duration
    }
    WidgetCard(title, accessory = {
        SegmentedControl(
            metrics,
            metric,
            { when (it) { ChartMetric.BOOKS -> L("Livres"); ChartMetric.PAGES -> L("Pages"); ChartMetric.HOURS -> L("Heures") } },
            { stored = it.key; preferences.edit().putString("home.chart.metric", it.key).apply() },
            Modifier.width(60.dp * metrics.size),
        )
    }) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
                val (value, caption) = when (metric) {
                    ChartMetric.BOOKS -> (booksPerYear.firstOrNull { it.year == currentYear }?.count ?: 0) to L("livres en %@", currentYear.toString())
                    ChartMetric.PAGES -> pagesPerMonth.sumOf { it.pages } to L("pages en %@", currentYear.toString())
                    ChartMetric.HOURS -> hoursPerMonth.sumOf { it.hours } to L("heures d'écoute en %@", currentYear.toString())
                }
                Text(number.format(value), style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = color)
                Text(caption, style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel, modifier = Modifier.padding(bottom = 4.dp))
            }
            val bars = when (metric) {
                ChartMetric.BOOKS -> booksPerYear.map { it.year.toString() to it.count }
                ChartMetric.PAGES -> pagesPerMonth.map { monthLetter(it.month) to it.pages }
                ChartMetric.HOURS -> hoursPerMonth.map { monthLetter(it.month) to it.hours }
            }
            val slots = if (metric == ChartMetric.BOOKS) bars else (1..12).map { m -> monthLetter(m) to (bars.getOrNull(m - 1)?.second ?: 0) }
            BarChart(slots, color)
        }
    }
}

private fun monthLetter(month: Int): String = Month.of(month).getDisplayName(DateStyle.NARROW_STANDALONE, Locale.getDefault())

@Composable
private fun BarChart(bars: List<Pair<String, Int>>, color: Color) {
    val measurer = rememberTextMeasurer()
    val faint = Shiori.colors.tertiaryLabel
    val top = maxOf(1.0, (bars.maxOfOrNull { it.second } ?: 0) * 1.2).toFloat()
    Canvas(Modifier.fillMaxWidth().height(100.dp)) {
        if (bars.isEmpty()) return@Canvas
        val slot = size.width / bars.size
        val bottom = size.height - 16.dp.toPx()
        val chartTop = 12.dp.toPx()
        bars.forEachIndexed { index, (label, value) ->
            val x = slot * index + slot / 2
            val height = (bottom - chartTop) * value / top
            val width = 14.dp.toPx()
            if (value > 0) {
                drawRoundRect(color, Offset(x - width / 2, bottom - height), Size(width, height), CornerRadius(3.dp.toPx()))
                val count = measurer.measure(NumberFormat.getIntegerInstance().format(value), TextStyle(fontSize = 9.sp, color = faint))
                drawText(count, topLeft = Offset(x - count.size.width / 2, bottom - height - count.size.height - 2.dp.toPx()))
            }
            val text = measurer.measure(label, TextStyle(fontSize = 11.sp, color = faint))
            drawText(text, topLeft = Offset(x - text.size.width / 2, bottom + 3.dp.toPx()))
        }
    }
}

/** The last book finished, or what the card will hold. */
@Composable
fun LastFinishedCard(book: Book?, onTap: (Book) -> Unit) {
    if (book == null) {
        WidgetCard(L("Dernier livre terminé")) { WidgetEmptyMessage(L("Terminez un livre pour le retrouver ici."), WidgetPlaceholder.BOOK) }
        return
    }
    val colors = Shiori.colors
    val finished = book.finishedAt
    val line = when (val days = finished?.daysAgo()) {
        null -> L("Dernier livre terminé")
        0 -> L("Dernier livre terminé · aujourd'hui")
        1 -> L("Dernier livre terminé · hier")
        else -> L("Dernier livre terminé · il y a %lldj", days)
    }
    val started = book.startedAt
    val detail = if (started != null && finished != null) {
        "${book.authorLine} · " + L("lu en %lld jours", ChronoUnit.DAYS.between(started, finished).toInt() + 1)
    } else {
        book.authorLine
    }
    Row(
        Modifier.fillMaxWidth().background(colors.secondaryGroupedBackground, RoundedCornerShape(20.dp)).plainClickable { onTap(book) }.padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        BookCover(book, 56.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(line, style = Shiori.type.caption, color = colors.secondaryLabel)
            Text(book.title, style = Shiori.type.headline, color = colors.label, maxLines = 2)
            Text(detail, style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
            book.rating?.let { RatingStars(it) }
        }
        Icon(Symbol("chevron.right"), null, Modifier.size(14.dp).align(Alignment.CenterVertically), tint = colors.tertiaryLabel)
    }
}

