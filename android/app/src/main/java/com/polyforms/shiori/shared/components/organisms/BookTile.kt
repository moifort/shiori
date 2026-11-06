package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.LocalCoverMaxPixelSize
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.styles.Symbol

/** A mosaic tile: the cover edge to edge, a heart and the status along its foot. */
@Composable
fun BookTile(book: Book, width: Dp, modifier: Modifier = Modifier, showsStatus: Boolean = true) {
    val pixels = with(LocalDensity.current) { (width * 1.5f).roundToPx() }
    val showsStatusGlyph = showsStatus && book.status != ReadingStatus.READ
    CompositionLocalProvider(LocalCoverMaxPixelSize provides ((pixels + 63) / 64 * 64)) {
        Box(modifier) {
            BookCover(book, width, showsFormatBadge = false, cornerRadius = 0.dp)
            if (book.favorite || showsStatusGlyph) {
                MosaicGlyphs(
                    leading = {
                        if (book.favorite && showsStatusGlyph) Icon(Symbol("heart.fill"), null, Modifier.size(11.dp), tint = Color.White)
                    },
                    trailing = {
                        if (showsStatusGlyph) {
                            Icon(Symbol(book.status.symbol), book.status.label, Modifier.size(11.dp), tint = Color.White)
                        } else if (book.favorite) {
                            Icon(Symbol("heart.fill"), null, Modifier.size(11.dp), tint = Color.White)
                        }
                    },
                )
            }
        }
    }
}
