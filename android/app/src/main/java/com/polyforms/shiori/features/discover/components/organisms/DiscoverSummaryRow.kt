package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/** A cover a strip scrolls to, by its place in the strip. */
data class CoverFocus(val id: String, val place: Int)

/** How wide a summary line's covers are. */
val SummaryCoverWidth = 68.dp

/**
 * One line of a summary card: its name and what it holds in a few words, its symbol in its colour
 * on the corner, over a strip of every cover it holds. A line may set a few books apart, drawn
 * whole between the heading and the strip; a line with no covers is the heading alone.
 */
@Composable
fun DiscoverSummaryRow(
    title: String,
    line: String,
    modifier: Modifier = Modifier,
    symbol: String? = null,
    tint: Color = Shiori.colors.accent,
    scrolledTo: CoverFocus? = null,
    lead: (@Composable () -> Unit)? = null,
    covers: (LazyListScope.() -> Unit)? = null,
) {
    val colors = Shiori.colors
    Column(modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(Modifier.padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(line, style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = if (covers == null) 2 else 1, overflow = TextOverflow.Ellipsis)
            }
            if (symbol != null) Icon(Symbol(symbol), null, Modifier.size(22.dp).align(Alignment.Top), tint = tint)
        }
        lead?.invoke()
        if (covers != null) {
            val state = rememberLazyListState()
            LaunchedEffect(scrolledTo) { scrolledTo?.let { state.animateScrollToItem(maxOf(0, it.place - 1)) } }
            LazyRow(
                state = state,
                contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 7.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.Top,
                content = covers,
            )
        }
    }
}
