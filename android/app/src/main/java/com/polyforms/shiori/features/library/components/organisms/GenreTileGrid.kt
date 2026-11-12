package com.polyforms.shiori.features.library.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.library.GenreShelf
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.color
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** The genres the reader holds, two to a row, each tinted with a cover tilted at its corner. */
@Composable
fun GenreTileGrid(genres: List<GenreShelf>, onOpen: (BookGenre) -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        genres.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEach { shelf -> Tile(shelf, Modifier.weight(1f)) { onOpen(shelf.genre) } }
                if (pair.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Tile(shelf: GenreShelf, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val tint = shelf.genre.tint.color()
    Box(
        modifier
            .heightIn(min = 74.dp)
            .clip(shape)
            .background(Color(0xFF1C1C1C))
            .background(Brush.linearGradient(listOf(tint.copy(alpha = 0.5f), tint.copy(alpha = 0.14f))))
            .border(1.dp, Color.White.copy(alpha = 0.22f), shape)
            .plainClickable(onClick = onClick),
    ) {
        shelf.coverURL?.let { url ->
            CoverImage(
                url,
                Modifier.align(Alignment.BottomEnd).offset(x = 6.dp, y = 14.dp).rotate(12f)
                    .shadow(7.dp, RoundedCornerShape(4.dp)).size(46.dp, 69.dp).clip(RoundedCornerShape(4.dp)),
            )
        }
        Column(Modifier.padding(start = 14.dp, end = 44.dp, top = 12.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(shelf.genre.label, style = Shiori.type.headline, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                if (shelf.count == 1) L("1 livre") else L("%lld livres", shelf.count),
                style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White.copy(alpha = 0.75f),
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun GenreTileGridPreview() = PreviewSurface {
    GenreTileGrid(
        listOf(
            com.polyforms.shiori.features.library.GenreShelf(com.polyforms.shiori.shared.BookGenre.SCIENCE_FICTION, 48, DebugFixtures.toRead[1].coverURL),
            com.polyforms.shiori.features.library.GenreShelf(com.polyforms.shiori.shared.BookGenre.FANTASY, 39, DebugFixtures.reading[0].coverURL),
            com.polyforms.shiori.features.library.GenreShelf(com.polyforms.shiori.shared.BookGenre.CRIME, 17),
        ),
        onOpen = {},
    )
}
