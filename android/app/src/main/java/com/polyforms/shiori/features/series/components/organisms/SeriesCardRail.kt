package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.features.home.components.organisms.SeriesShowCard
import com.polyforms.shiori.features.series.progress
import com.polyforms.shiori.features.series.releaseTag
import com.polyforms.shiori.shared.FollowedSeries

/** One card of a [SeriesCardRail]. */
data class SeriesRailCard(val progress: Dashboard.SeriesProgress, val tag: String? = null, val open: () -> Unit) {
    val id: String get() = progress.id
}

private val cardWidth = 200.dp
private val cardHeight = 128.dp
private const val TWO_ROWS_FROM = 4

/** Saga cards scrolling sideways, on two rows from four sagas. */
@Composable
fun SeriesCardRail(cards: List<SeriesRailCard>, modifier: Modifier = Modifier, inset: Dp = 20.dp) {
    val rows = if (cards.size >= TWO_ROWS_FROM) 2 else 1
    LazyHorizontalGrid(
        GridCells.Fixed(rows),
        modifier.height(cardHeight * rows + 13.dp * (rows - 1)),
        contentPadding = PaddingValues(horizontal = inset),
        horizontalArrangement = Arrangement.spacedBy(13.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        items(cards, key = { it.id }) { card ->
            SeriesShowCard(card.progress, Modifier.size(cardWidth, cardHeight), tag = card.tag, isCompact = true, onOpen = card.open)
        }
    }
}

@Composable
fun SeriesCardRail(series: List<FollowedSeries>, modifier: Modifier = Modifier, onOpen: (FollowedSeries) -> Unit) =
    SeriesCardRail(series.map { saga -> SeriesRailCard(saga.progress, saga.releaseTag) { onOpen(saga) } }, modifier)
