package com.polyforms.shiori.shared.book

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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable

/** A book's saga under its facts: the volumes as posters, the open one ringed, centred. */
@Composable
fun SeriesVolumesRow(
    name: String,
    volumes: List<SeriesStripItem>,
    currentId: String,
    onOpenSeries: () -> Unit,
    onOpenVolume: (Book) -> Unit,
) {
    val state = rememberLazyListState()
    LaunchedEffect(volumes.map { it.id }) {
        val index = volumes.indexOfFirst { it.id == currentId }
        if (index > 0) state.scrollToItem(maxOf(0, index - 1))
    }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(name, style = RowHeaderStyle.INLINE, action = onOpenSeries)
        LazyRow(
            state = state,
            horizontalArrangement = Arrangement.spacedBy(13.dp),
            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp),
            modifier = Modifier.padding(horizontal = (-6).dp.coerceAtLeast(0.dp)),
        ) {
            items(volumes, key = { it.id }) { item ->
                when (item) {
                    is SeriesStripItem.Owned -> {
                        val volume = item.book
                        val current = volume.id == currentId
                        Box(
                            Modifier
                                .plainClickable { if (!current) onOpenVolume(volume) }
                                .then(
                                    if (current) Modifier.border(2.dp, Shiori.colors.label, RoundedCornerShape(11.dp)).padding(4.dp)
                                    else Modifier.padding(4.dp),
                                ),
                        ) {
                            PosterCover(volume, caption(volume), showsEditionTags = false)
                        }
                    }
                    is SeriesStripItem.Missing -> {
                        val caption = item.number?.let { L("Tome %lld", it) } ?: item.title
                        val day = if (item.forthcoming) item.date?.let(ReleaseDateText::short) else null
                        Box(Modifier.plainClickable(onClick = onOpenSeries).padding(4.dp)) {
                            PosterCover(
                                Book(id = item.id, title = item.title, authors = emptyList(), coverURL = item.coverURL, status = ReadingStatus.TO_READ),
                                day ?: caption,
                                Modifier.alpha(if (day != null) 1f else if (item.forthcoming) 0.3f else 0.45f),
                                showsEditionTags = false,
                                dimming = if (day == null) 0.12 else 0.5,
                            )
                        }
                    }
                }
            }
        }
    }
}

/** "Tome 3", or the kind of an annex, or the title of a book outside the numbering. */
private fun caption(volume: Book): String {
    val series = volume.series ?: return volume.title
    val number = series.volume ?: return series.kind.label
    return L("Tome %lld", number)
}
