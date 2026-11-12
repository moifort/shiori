package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A titled row of posters, the volume to read next ringed and scrolled into view. */
@Composable
fun <Item> SeriesPosterRail(title: String, items: List<Item>, id: (Item) -> String, ringedId: String? = null, poster: @Composable (Item) -> Unit) {
    val state = rememberLazyListState()
    LaunchedEffect(items.map(id), ringedId) {
        val index = items.indexOfFirst { id(it) == ringedId }
        if (index > 0) state.scrollToItem(maxOf(0, index - 1))
    }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(title)
        LazyRow(state = state, horizontalArrangement = Arrangement.spacedBy(13.dp), contentPadding = PaddingValues(6.dp)) {
            items(items, key = id) { item ->
                Box(
                    if (id(item) == ringedId) Modifier.border(2.dp, Shiori.colors.label, RoundedCornerShape(11.dp)).padding(4.dp) else Modifier.padding(4.dp),
                ) { poster(item) }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SeriesPosterRailPreview() = PreviewSurface {
    SeriesPosterRail("À lire", DebugFixtures.toRead, id = { it.id }, ringedId = DebugFixtures.toRead[0].id) {
        com.polyforms.shiori.shared.components.organisms.BookCover(it, width = 100.dp)
    }
}
