package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.components.styles.Shiori

/** A cover with one line under it: a date, a progress, an author. */
@Composable
fun CoverTile(
    book: Book,
    caption: String,
    modifier: Modifier = Modifier,
    width: Dp = 84.dp,
    captionTint: Color? = null,
    captionTruncatesHead: Boolean = false,
) {
    Column(modifier.width(width), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        BookCover(book, width, formatBadgeSize = 22.dp)
        if (caption.isNotEmpty()) {
            Text(
                caption,
                style = Shiori.type.caption2,
                color = captionTint ?: Shiori.colors.secondaryLabel,
                maxLines = 1,
                overflow = if (captionTruncatesHead) TextOverflow.StartEllipsis else TextOverflow.Ellipsis,
            )
        }
    }
}
