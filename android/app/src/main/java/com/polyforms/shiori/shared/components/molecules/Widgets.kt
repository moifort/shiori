package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriVerticalDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import java.text.NumberFormat
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A dashboard card: a headline, an optional accessory and chevron, then its content. */
@Composable
fun WidgetCard(
    title: String,
    modifier: Modifier = Modifier,
    action: (() -> Unit)? = null,
    accessory: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = Shiori.colors
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.secondaryGroupedBackground)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().then(if (action != null) Modifier.plainClickable(onClick = action) else Modifier),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = Shiori.type.headline, color = colors.label)
            Spacer(Modifier.weight(1f))
            accessory()
            if (action != null) Icon(Symbol("chevron.right"), null, Modifier.size(16.dp), tint = colors.tertiaryLabel)
        }
        content()
    }
}

enum class WidgetPlaceholder { COVERS, BOOK, ROWS, SEGMENTS, RINGS }

/** What an empty card says, over a faint sketch of what it will hold. */
@Composable
fun WidgetEmptyMessage(text: String, placeholder: WidgetPlaceholder? = null) {
    val colors = Shiori.colors
    val sketch = colors.quaternaryLabel
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        when (placeholder) {
            WidgetPlaceholder.COVERS -> Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                repeat(4) { Box(Modifier.size(64.dp, 96.dp).background(sketch, RoundedCornerShape(6.dp))) }
            }
            WidgetPlaceholder.BOOK -> Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.size(44.dp, 66.dp).background(sketch, RoundedCornerShape(4.dp)))
                SketchLines(listOf(0.5f, 0.8f, 0.4f), sketch)
            }
            WidgetPlaceholder.ROWS -> SketchLines(listOf(0.7f, 0.55f), sketch)
            WidgetPlaceholder.SEGMENTS -> Row(Modifier.fillMaxWidth().height(12.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                listOf(0.4f, 0.25f, 0.2f, 0.15f).forEach { Box(Modifier.weight(it).fillMaxHeight().background(sketch, CircleShape)) }
            }
            WidgetPlaceholder.RINGS -> Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                repeat(2) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Canvas(Modifier.size(34.dp)) { drawCircle(sketch, style = Stroke(5.dp.toPx())) }
                        Box(Modifier.width(70.dp)) { SketchLines(listOf(0.9f, 0.5f), sketch) }
                    }
                }
            }
            null -> Unit
        }
        Text(text, style = Shiori.type.subheadline, color = colors.secondaryLabel)
    }
}

@Composable
private fun SketchLines(widths: List<Float>, color: Color) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        widths.forEach { Box(Modifier.fillMaxWidth(it).height(9.dp).background(color, CircleShape)) }
    }
}

/** One figure of a line: "83" over "LUS". */
data class Figure(val value: String, val label: String)

/** Figures side by side, split by hairlines; scrolls when they do not fit. */
@Composable
fun FiguresLine(items: List<Figure>) {
    val colors = Shiori.colors
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEachIndexed { index, item ->
            if (index > 0) ShioriVerticalDivider(Modifier.height(30.dp).padding(horizontal = 8.dp))
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(item.value, style = Shiori.type.title2, color = colors.label)
                Text(
                    item.label.uppercase(),
                    style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                    color = colors.secondaryLabel,
                    maxLines = 1,
                )
            }
        }
    }
}

object Figures {
    /** "1,2k" past a thousand, the figure itself below. */
    fun compact(value: Int): String {
        val format = NumberFormat.getNumberInstance()
        if (value < 1000) return format.format(value)
        val thousands = value / 1000.0
        format.maximumFractionDigits = if (thousands < 10) 1 else 0
        return format.format(thousands) + "k"
    }
}

/** One part of a segmented bar. */
data class Segment(val id: String, val label: String, val value: Int, val color: Color)

/** A bar cut in proportion to its parts, each labelled with its figure, and a legend under it. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SegmentedBar(segments: List<Segment>) {
    val total = maxOf(1, segments.sumOf { it.value })
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth().height(22.dp).clip(CircleShape)) {
            val spacing = 2.dp
            val available = maxWidth - spacing * maxOf(0, segments.size - 1)
            Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                segments.forEach { segment ->
                    val width = available * (segment.value.toFloat() / total)
                    Box(Modifier.width(width).fillMaxHeight().background(segment.color), contentAlignment = Alignment.Center) {
                        if (width >= 26.dp) {
                            Text(
                                NumberFormat.getNumberInstance().format(segment.value),
                                style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
                                color = Color.White,
                            )
                        }
                    }
                }
            }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            segments.forEach { segment ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(8.dp).background(segment.color, CircleShape))
                    Text(segment.label, style = Shiori.type.caption, color = Shiori.colors.secondaryLabel)
                }
            }
        }
    }
}

/** A capsule label: a subgenre, a filter. */
@Composable
fun Pill(
    text: String,
    symbol: String? = null,
    style: TextStyle = Shiori.type.caption,
    tint: Color? = null,
    trailingSymbol: String? = null,
) {
    val colors = Shiori.colors
    val foreground = tint ?: colors.label
    Row(
        Modifier
            .background(tint?.copy(alpha = 0.15f) ?: colors.quaternaryLabel, CircleShape)
            .padding(horizontal = 10.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (symbol != null) Icon(Symbol(symbol), null, Modifier.size(12.dp), tint = foreground)
        Text(text, style = style, color = foreground, maxLines = 1)
        if (trailingSymbol != null) Icon(Symbol(trailingSymbol), null, Modifier.size(12.dp), tint = foreground)
    }
}

/** Pills that wrap onto as many lines as they need. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TagList(tags: List<String>, symbol: String? = null) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        tags.forEach { Pill(it, symbol) }
    }
}

/** One choice of a pill row. */
data class FilterPill(val id: String, val label: String)

/** A scrolling row of pills, "Tout" first; the chosen one drawn in ink. */
@Composable
fun FilterPills(pills: List<FilterPill>, selected: String?, onSelect: (String?) -> Unit, allLabel: String? = L("Tout")) {
    val colors = Shiori.colors
    @Composable
    fun pill(label: String, on: Boolean, action: () -> Unit) {
        Box(
            Modifier
                .height(34.dp)
                .clip(CircleShape)
                .background(if (on) colors.label else colors.secondaryGroupedBackground)
                .plainClickable(onClick = action)
                .padding(horizontal = 15.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                label,
                style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
                color = if (on) colors.background else colors.label,
                maxLines = 1,
            )
        }
    }
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (allLabel != null) pill(allLabel, selected == null) { onSelect(null) }
        pills.forEach { item -> pill(item.label, selected == item.id) { onSelect(item.id) } }
    }
}

@Preview(showBackground = true)
@Composable
private fun WidgetsPreview() = PreviewSurface {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        WidgetCard("Genres", action = {}) {
            FiguresLine(listOf(Figure("142", "lus"), Figure("27", "à lire"), Figure("15", "coups de cœur")))
            SegmentedBar(
                listOf(
                    Segment("sf", "Science-fiction", 48, Shiori.colors.blue),
                    Segment("fantasy", "Fantasy", 39, Shiori.colors.purple),
                    Segment("crime", "Polar", 17, Shiori.colors.orange),
                ),
            )
            TagList(listOf("Aventure", "Space opera"), symbol = "tag")
        }
        WidgetCard("Lectures") { WidgetEmptyMessage("Rien de lu cette année.", WidgetPlaceholder.COVERS) }
        Pill("Nouveau", symbol = "sparkles")
        FilterPills(listOf(FilterPill("book", "Livres"), FilterPill("manga", "Mangas")), selected = null, onSelect = {}, allLabel = "Tout")
    }
}
