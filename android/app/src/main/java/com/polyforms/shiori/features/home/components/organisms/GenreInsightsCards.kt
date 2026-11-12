package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.features.home.GenreInsights
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.Pill
import com.polyforms.shiori.shared.components.molecules.WidgetCard
import com.polyforms.shiori.shared.components.styles.AudibleOrange
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.ShioriVerticalDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.color
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

private val genreCount = BookGenre.entries.size - 1

/** The six genres read most, as a smoothed polygon over rings, each named at its spoke. */
@Composable
fun GenreRadar(shares: List<GenreInsights.Share>) {
    val axes = shares.take(6)
    if (axes.size < 3) return
    val tint = axes.first().genre.tint.color()
    val ring = Shiori.colors.secondaryLabel.copy(alpha = 0.18f)
    val top = (axes.maxOf { it.count }).toFloat()
    val values = axes.map { it.count / top }
    BoxWithConstraints(Modifier.fillMaxWidth().height(320.dp)) {
        val density = LocalDensity.current
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }
        val radius = minOf(widthPx, heightPx) / 2 - with(density) { 48.dp.toPx() }
        val center = Offset(widthPx / 2, heightPx / 2)
        fun point(index: Int, distance: Float): Offset {
            val angle = -Math.PI / 2 + 2 * Math.PI * index / axes.size
            return Offset(center.x + distance * cos(angle).toFloat(), center.y + distance * sin(angle).toFloat())
        }
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(Brush.radialGradient(listOf(tint.copy(alpha = 0.14f), tint.copy(alpha = 0.02f)), center, radius), radius, center)
            listOf(1f, 2f / 3, 1f / 3).forEach { drawCircle(ring, radius * it, center, style = Stroke(1.dp.toPx())) }
            axes.indices.forEach { drawLine(ring, center, point(it, radius), 1.dp.toPx()) }
            val points = values.mapIndexed { index, value -> point(index, radius * value) }
            val path = Path().apply {
                moveTo(points[0].x, points[0].y)
                val n = points.size
                for (i in 0 until n) {
                    val previous = points[(i - 1 + n) % n]
                    val current = points[i]
                    val next = points[(i + 1) % n]
                    val afterNext = points[(i + 2) % n]
                    cubicTo(
                        current.x + (next.x - previous.x) / 6, current.y + (next.y - previous.y) / 6,
                        next.x - (afterNext.x - current.x) / 6, next.y - (afterNext.y - current.y) / 6,
                        next.x, next.y,
                    )
                }
                close()
            }
            drawPath(path, Brush.verticalGradient(listOf(tint.copy(alpha = 0.55f), tint.copy(alpha = 0.18f))))
            drawPath(path, tint, style = Stroke(2.5.dp.toPx(), join = StrokeJoin.Round))
        }
        val labelDistance = radius + with(density) { 26.dp.toPx() }
        axes.forEachIndexed { index, share ->
            val at = point(index, labelDistance)
            Layout({
                Row(
                    Modifier.clip(CircleShape).background(Shiori.colors.secondaryGroupedBackground).border(0.5.dp, Shiori.colors.separator, CircleShape)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Symbol(share.genre.symbol), null, Modifier.size(12.dp), tint = share.genre.tint.color())
                    Text(share.genre.label, style = Shiori.type.caption.copy(fontWeight = FontWeight.Medium), color = Shiori.colors.label, maxLines = 1)
                }
            }) { measurables, constraints ->
                val placeable = measurables.first().measure(constraints.copy(minWidth = 0, minHeight = 0))
                layout(constraints.maxWidth, constraints.maxHeight) {
                    placeable.place(IntOffset((at.x - placeable.width / 2).roundToInt(), (at.y - placeable.height / 2).roundToInt()))
                }
            }
        }
    }
}

/** The reader's leading genre in a ring, the next two in bars, and how many genres they read. */
@Composable
fun GenreSignatureCard(readCount: Int, shares: List<GenreInsights.Share>) {
    val first = shares.firstOrNull() ?: return
    val colors = Shiori.colors
    val tint = first.genre.tint.color()
    fun share(entry: GenreInsights.Share) = if (readCount > 0) entry.count.toFloat() / readCount else 0f
    fun percent(entry: GenreInsights.Share) = (share(entry) * 100).roundToInt()
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(colors.secondaryGroupedBackground)
            .background(Brush.linearGradient(0f to tint.copy(alpha = 0.22f), 0.5f to Color.Transparent)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(L("Votre signature"), style = Shiori.type.headline, color = colors.label)
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(76.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    val stroke = 9.dp.toPx()
                    val inset = stroke / 2
                    drawArc(tint.copy(alpha = 0.15f), 0f, 360f, false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke))
                    drawArc(tint, -90f, 360f * share(first), false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Icon(Symbol(first.genre.symbol), null, Modifier.size(26.dp), tint = tint)
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(first.genre.label, style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = colors.label, maxLines = 1)
                Text(L("%lld%% de vos lectures", percent(first)), style = Shiori.type.subheadline, color = colors.secondaryLabel)
            }
        }
        if (shares.size > 1) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                shares.drop(1).take(2).forEach { entry ->
                    val entryTint = entry.genre.tint.color()
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Symbol(entry.genre.symbol), null, Modifier.size(16.dp).width(22.dp), tint = entryTint)
                        Text(entry.genre.label, style = Shiori.type.subheadline, color = colors.label, maxLines = 1, modifier = Modifier.width(120.dp))
                        Box(Modifier.weight(1f).height(8.dp).clip(CircleShape).background(entryTint.copy(alpha = 0.15f))) {
                            Box(Modifier.fillMaxWidth(share(entry)).height(8.dp).clip(CircleShape).background(entryTint))
                        }
                        Text("${percent(entry)}%", style = Shiori.type.caption.copy(fontWeight = FontWeight.Medium), color = colors.secondaryLabel, modifier = Modifier.width(34.dp))
                    }
                }
            }
        }
        ShioriDivider()
        Row(verticalAlignment = Alignment.CenterVertically) {
            Figure(readCount.toString(), L("livres lus"), Modifier.weight(1f))
            ShioriVerticalDivider(Modifier.height(32.dp))
            Figure(L("%lld sur %lld", shares.size, genreCount), L("genres explorés"), Modifier.weight(1f))
        }
    }
}

@Composable
private fun Figure(value: String, caption: String, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, style = Shiori.type.title3.copy(fontWeight = FontWeight.SemiBold), color = Shiori.colors.label)
        Text(caption, style = Shiori.type.caption, color = Shiori.colors.secondaryLabel)
    }
}

/** A format's colour in the charts. */
val BookFormat.chartColor: Color
    @Composable get() = when (this) {
        BookFormat.BOOK -> Shiori.colors.blue
        BookFormat.AUDIOBOOK -> AudibleOrange
        BookFormat.BANDE_DESSINEE -> Shiori.colors.purple
        BookFormat.COMIC -> Shiori.colors.red
        BookFormat.MANGA -> Shiori.colors.pink
    }

/** The formats read, in a bar cut in proportion, then one line each. */
@Composable
fun FormatsCard(formats: List<GenreInsights.FormatShare>) {
    val total = maxOf(1, formats.sumOf { it.count })
    val colors = Shiori.colors
    WidgetCard(L("Formats")) {
        Row(Modifier.fillMaxWidth().height(12.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            formats.forEach { Box(Modifier.weight(maxOf(it.count, 1).toFloat()).fillMaxSize().background(it.format.chartColor)) }
        }
        Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            formats.forEach { share ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Symbol(share.format.symbol), null, Modifier.size(20.dp), tint = share.format.chartColor)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(share.format.label, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                        share.topGenre?.let { Text(L("Surtout %@", it.label), style = Shiori.type.subheadline, color = colors.secondaryLabel) }
                    }
                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("${share.count}", style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                        Text("${(share.count * 100.0 / total).roundToInt()}%", style = Shiori.type.caption, color = colors.secondaryLabel)
                    }
                }
            }
        }
    }
}

/** Genres plotted by how much they are read and how well they are rated, in four quarters. */
@Composable
fun TasteMap(tastes: List<GenreInsights.Taste>, averageRating: Double, gem: GenreInsights.Taste?) {
    val counts = tastes.map { it.readCount }.sorted()
    val median = if (counts.isEmpty()) 0.0 else if (counts.size % 2 == 0) (counts[counts.size / 2 - 1] + counts[counts.size / 2]) / 2.0 else counts[counts.size / 2].toDouble()
    val lowest = tastes.minOfOrNull { it.averageRating } ?: 3.0
    val floor = minOf(3.0, Math.floor((lowest - 0.3) * 2) / 2)
    val ceiling = 5.4
    val countCeiling = (tastes.maxOfOrNull { it.readCount } ?: 1) + 2.0
    val measurer = rememberTextMeasurer()
    val colors = Shiori.colors
    val quarters = listOf(colors.orange, colors.green, colors.red, colors.gray)
    val labelColor = colors.secondaryLabel
    val axisColor = colors.tertiaryLabel
    val tints = tastes.associate { it.id to it.genre.tint.color() }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(Modifier.padding(horizontal = 12.dp), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Canvas(Modifier.fillMaxWidth().height(280.dp)) {
                val left = 28.dp.toPx()
                val bottomAxis = 18.dp.toPx()
                val plot = Size(size.width - left, size.height - bottomAxis)
                fun x(count: Double) = left + plot.width * (count / countCeiling).toFloat()
                fun y(rating: Double) = plot.height * ((ceiling - rating) / (ceiling - floor)).toFloat()
                val splitX = x(median)
                val splitY = y(averageRating)
                listOf(
                    Triple(Offset(left, 0f), Size(splitX - left, splitY), quarters[0]),
                    Triple(Offset(splitX, 0f), Size(size.width - splitX, splitY), quarters[1]),
                    Triple(Offset(left, splitY), Size(splitX - left, plot.height - splitY), quarters[2]),
                    Triple(Offset(splitX, splitY), Size(size.width - splitX, plot.height - splitY), quarters[3]),
                ).forEach { (origin, area, color) -> drawRect(color.copy(alpha = 0.12f), origin, area) }
                listOf(L("À creuser") to Offset(left + 6, 6f), L("Valeurs sûres") to Offset(size.width - 6, 6f), L("Déceptions") to Offset(left + 6, plot.height - 6), L("Habitudes") to Offset(size.width - 6, plot.height - 6))
                    .forEachIndexed { index, (text, at) ->
                        val layout = measurer.measure(text, TextStyle(fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = quarters[index].copy(alpha = 0.85f)))
                        val dx = if (index % 2 == 1) -layout.size.width.toFloat() else 0f
                        val dy = if (index >= 2) -layout.size.height.toFloat() else 0f
                        drawText(layout, topLeft = Offset(at.x + dx, at.y + dy))
                    }
                var rating = Math.ceil(floor)
                while (rating <= 5) {
                    val layout = measurer.measure("★${rating.toInt()}", TextStyle(fontSize = 10.sp, color = axisColor))
                    drawText(layout, topLeft = Offset(0f, y(rating) - layout.size.height / 2))
                    rating += 1
                }
                val step = if (countCeiling > 12) 5 else 2
                var tick = 0
                while (tick <= countCeiling) {
                    val layout = measurer.measure("$tick", TextStyle(fontSize = 10.sp, color = axisColor))
                    drawText(layout, topLeft = Offset(x(tick.toDouble()) - layout.size.width / 2, plot.height + 3.dp.toPx()))
                    tick += step
                }
                val taken = mutableListOf<androidx.compose.ui.geometry.Rect>()
                tastes.sortedByDescending { it.readCount }.forEach { taste ->
                    val tint = tints.getValue(taste.id)
                    val bubble = (12 + 14 * taste.readCount / countCeiling).dp.toPx()
                    val centre = Offset(x(taste.readCount.toDouble()), y(taste.averageRating))
                    if (taste == gem) drawCircle(tint.copy(alpha = 0.5f), bubble / 2 + 5.dp.toPx(), centre, style = Stroke(1.5.dp.toPx()))
                    drawCircle(tint, bubble / 2, centre)
                    drawCircle(Color.White, bubble / 2, centre, style = Stroke(2.dp.toPx()))
                    val label = measurer.measure(taste.label, TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = if (taste == gem) tint else labelColor))
                    val reach = bubble / 2 + (if (taste == gem) 7 else 4).dp.toPx()
                    val candidates = listOf(
                        Offset(centre.x + reach, centre.y - label.size.height / 2),
                        Offset(centre.x - reach - label.size.width, centre.y - label.size.height / 2),
                        Offset(centre.x - label.size.width / 2, centre.y + reach - 2),
                    ).map { androidx.compose.ui.geometry.Rect(it, Size(label.size.width.toFloat(), label.size.height.toFloat())) }
                    val bounds = androidx.compose.ui.geometry.Rect(-24f, -8f, size.width + 24, plot.height + 8)
                    fun cost(rect: androidx.compose.ui.geometry.Rect): Float {
                        val overlap = taken.sumOf { other -> other.intersect(rect).let { if (it.width > 0 && it.height > 0) (it.width * it.height).toDouble() else 0.0 } }
                        val inside = bounds.intersect(rect).let { if (it.width > 0 && it.height > 0) it.width * it.height else 0f }
                        return (overlap + rect.width * rect.height - inside).toFloat()
                    }
                    val best = candidates.firstOrNull { cost(it) == 0f } ?: candidates.minBy { cost(it) }
                    taken += androidx.compose.ui.geometry.Rect(centre - Offset(bubble / 2, bubble / 2), Size(bubble, bubble))
                    taken += best
                    drawText(label, topLeft = best.topLeft)
                }
            }
            Text(L("Livres lus"), style = Shiori.type.caption, color = colors.secondaryLabel)
        }
        if (gem != null) {
            val tint = gem.genre.tint.color()
            Row(
                Modifier.fillMaxWidth().background(tint.copy(alpha = 0.1f), RoundedCornerShape(14.dp)).padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Symbol("sparkles"), null, Modifier.size(22.dp), tint = tint)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(L("Pépite sous-explorée"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                    Text(
                        L("%@ : %@ ★ en moyenne, sur %lld livres seulement.", gem.label, String.format("%.1f", gem.averageRating), gem.readCount),
                        style = Shiori.type.subheadline,
                        color = colors.secondaryLabel,
                    )
                }
            }
        }
    }
}

/** The genre of the longest books, the one read fastest, the one most dropped. */
@Composable
fun GenreRecordsCard(longest: GenreInsights.LongestRecord?, fastest: GenreInsights.FastestRecord?, mostDropped: GenreInsights.DroppedRecord?) {
    val colors = Shiori.colors
    WidgetCard(L("Records par genre")) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            @Composable
            fun Line(symbol: String, tint: Color, title: String, genre: BookGenre, detail: String) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Symbol(symbol), null, Modifier.size(24.dp), tint = tint)
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                        Text("${genre.label} · $detail", style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    }
                }
            }
            longest?.let { Line("books.vertical", colors.indigo, L("Le pavé"), it.genre, L("%lld pages en moyenne", it.averagePages)) }
            fastest?.let { Line("hare", colors.green, L("Le plus dévoré"), it.genre, L("%lld jours par livre", it.averageDays)) }
            mostDropped?.let { Line("hand.thumbsdown", colors.red, L("Le plus abandonné"), it.genre, L("%lld sur %lld commencés", it.droppedCount, it.startedCount)) }
        }
    }
}

/** The genres never read, those with books waiting on the pile marked. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun UnexploredGenresCard(unexplored: List<GenreInsights.Unexplored>) {
    WidgetCard(L("Terres inexplorées"), accessory = {
        Text(L("%lld sur %lld", unexplored.size, genreCount), style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel)
    }) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            unexplored.forEach { item ->
                if (item.pileCount > 0) {
                    Pill(L("%@ · %lld sur la pile", item.genre.label, item.pileCount), "bookmark", tint = item.genre.tint.color())
                } else {
                    Pill(item.genre.label)
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun GenreInsightsCardsPreview() = PreviewSurface {
    val insights = DebugFixtures.genreInsights
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        GenreSignatureCard(insights.readCount, insights.shares)
        FormatsCard(insights.formats)
        TasteMap(insights.tastes, insights.averageRating ?: 0.0, insights.gem)
        GenreRecordsCard(insights.longest, insights.fastest, insights.mostDropped)
        UnexploredGenresCard(insights.unexplored)
    }
}
