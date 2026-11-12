package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.series.NextVolume
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** "À suivre": the volume to read next of every saga under way. */
@Composable
fun SeriesUpNextRail(upNext: List<Pair<FollowedSeries, NextVolume>>, onOpen: (FollowedSeries) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(L("À suivre"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
        PosterRow(upNext.map { (series, volume) -> item(series, volume) { onOpen(series) } }) {}
    }
}

private fun item(series: FollowedSeries, volume: NextVolume, open: () -> Unit): PosterRowItem = when (volume) {
    is NextVolume.Owned -> {
        val book = volume.book
        val caption = book.series?.volume?.let { L("Tome %lld", it) } ?: book.title
        PosterRowItem(book, PosterLabel(caption, marksReading = book.status == ReadingStatus.READING), open)
    }
    is NextVolume.Missing -> {
        val book = Book(
            id = "next-${series.id}",
            title = volume.title,
            authors = listOfNotNull(series.author),
            format = if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            language = series.language,
            coverURL = volume.coverURL,
            status = ReadingStatus.TO_READ,
        )
        PosterRowItem(book, volume.number?.let { L("Tome %lld", it) } ?: volume.title, open)
    }
}

@Preview(showBackground = true)
@Composable
private fun SeriesUpNextRailPreview() = PreviewSurface {
    SeriesUpNextRail(
        listOf(DebugFixtures.followedSeries[0] to com.polyforms.shiori.features.series.NextVolume.Owned(DebugFixtures.reading[2])),
        onOpen = {},
    )
}
