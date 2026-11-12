package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.components.styles.Shiori
import java.time.Instant
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.max
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Column
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

enum class ShelfLayout { LIST, MOSAIC }

/**
 * Covers edge to edge, as many as fit at about 95 wide, with the month they were shelved in
 * tagged every few lines and pinned at the top while its covers scroll by.
 */
@Composable
fun <Row> ShelfMosaic(
    rows: List<Row>,
    id: (Row) -> Any,
    modifier: Modifier = Modifier,
    idealTileWidth: Dp = 95.dp,
    spacing: Dp = 2.dp,
    margin: Dp = 0.dp,
    columns: Int? = null,
    tileAspect: Float = 1.5f,
    date: ((Row) -> Instant?)? = null,
    scrolledTo: Any? = null,
    contentPadding: PaddingValues = PaddingValues(),
    header: (@Composable () -> Unit)? = null,
    bottom: @Composable () -> Unit = {},
    tile: @Composable (Row, Dp) -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        val fitting = max(3, ((maxWidth - margin * 2 + spacing) / (idealTileWidth + spacing)).toInt())
        val count = columns ?: fitting
        val tileWidth = (maxWidth - margin * 2 - spacing * (count - 1)) / count
        val isCompact = tileWidth < 80.dp
        val tags = remember(rows, count) { monthTags(rows, count, date) }
        val state = rememberLazyGridState()
        val headerCount = if (header != null) 1 else 0
        LaunchedEffect(scrolledTo, rows) {
            val index = rows.indexOfFirst { id(it) == scrolledTo }
            if (scrolledTo != null && index >= 0) state.animateScrollToItem(index + headerCount)
        }
        val pinned by remember(tags, headerCount) {
            derivedStateOf {
                val first = state.firstVisibleItemIndex - headerCount
                tags.keys.filter { it <= first }.maxOrNull()
            }
        }
        LazyVerticalGrid(
            GridCells.Fixed(count),
            state = state,
            contentPadding = contentPadding,
            horizontalArrangement = Arrangement.spacedBy(spacing),
            verticalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier.fillMaxSize().padding(horizontal = margin),
        ) {
            if (header != null) item(span = { GridItemSpan(maxLineSpan) }) { header() }
            items(rows.size, key = { id(rows[it]) }) { index ->
                Box {
                    tile(rows[index], tileWidth)
                    val month = tags[index]
                    if (month != null && index > (pinned ?: -1)) MosaicDateTag(month, isCompact)
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }) { bottom() }
        }
        val pinnedMonth = pinned?.let { tags[it] }
        if (pinnedMonth != null) {
            Box(Modifier.padding(start = margin, top = contentPadding.calculateTopPadding())) { MosaicDateTag(pinnedMonth, isCompact) }
        }
    }
}

private fun <Row> monthTags(rows: List<Row>, columns: Int, date: ((Row) -> Instant?)?): Map<Int, Instant> {
    if (date == null) return emptyMap()
    val tags = mutableMapOf<Int, Instant>()
    var taggedMonth: Pair<Int, Int>? = null
    var lastTaggedLine = Int.MIN_VALUE / 2
    var index = 0
    while (index < rows.size) {
        val line = index / columns
        val day = date(rows[index])
        if (line - lastTaggedLine >= 3 && day != null) {
            val local = DateText.local(day)
            val month = local.year to local.monthValue
            if (month != taggedMonth || line - lastTaggedLine >= 4) {
                tags[index] = day
                taggedMonth = month
                lastTaggedLine = line
            }
        }
        index += columns
    }
    return tags
}

/** "oct. 2026" in white on a dark veil, at a tile's top left. */
@Composable
fun MosaicDateTag(month: Instant, isCompact: Boolean = false) {
    val local = DateText.local(month)
    val name = local.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())
    val text = if (isCompact) "$name ${local.year % 100}" else "$name ${local.year}"
    Text(
        text,
        style = if (isCompact) Shiori.type.footnote.copy(fontSize = 13.sp, fontWeight = FontWeight.Bold) else Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold),
        color = Color.White,
        maxLines = 1,
        modifier = Modifier
            .padding(if (isCompact) 3.dp else 4.dp)
            .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(if (isCompact) 5.dp else 6.dp))
            .padding(horizontal = if (isCompact) 6.dp else 7.dp, vertical = if (isCompact) 3.dp else 4.dp),
    )
}

/** The glyphs along a tile's foot, white over a short darkening. */
@Composable
fun BoxScope.MosaicGlyphs(leading: @Composable RowScope.() -> Unit = {}, trailing: @Composable RowScope.() -> Unit = {}) {
    Box(
        Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.35f)))),
    ) {
        CompositionLocalProvider(LocalContentColor provides Color.White) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 5.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                leading()
                Spacer(Modifier.weight(1f))
                trailing()
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun MosaicDateTagPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        MosaicDateTag(java.time.Instant.now())
        MosaicDateTag(java.time.Instant.now(), isCompact = true)
    }
}
