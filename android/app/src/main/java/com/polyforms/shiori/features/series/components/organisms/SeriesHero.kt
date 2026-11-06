package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/** Three covers of a saga, fanned: the one in the middle, and its neighbours tilted behind. */
data class SeriesFan(val leading: Book? = null, val middle: Book? = null, val trailing: Book? = null) {
    companion object {
        fun of(volumes: List<Book>, centredOn: Int): SeriesFan {
            if (volumes.isEmpty()) return SeriesFan()
            val centre = centredOn.coerceIn(0, volumes.lastIndex)
            val before = centre - 1
            val after = centre + 1
            val hasBefore = before in volumes.indices
            val hasAfter = after in volumes.indices
            return when {
                hasBefore && hasAfter -> SeriesFan(volumes[before], volumes[centre], volumes[after])
                hasAfter -> SeriesFan(volumes.getOrNull(after + 1), volumes[centre], volumes[after])
                hasBefore -> SeriesFan(volumes[before], volumes[centre], volumes.getOrNull(before - 1))
                else -> SeriesFan(middle = volumes[centre])
            }
        }
    }
}

/** The head of a saga's page: the fanned covers, its name and author on their wash, and the buttons. */
@Composable
fun SeriesHero(
    name: String,
    author: String,
    fan: SeriesFan,
    language: BookLanguage? = null,
    onOpenAuthor: (() -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    val coverWidth = 156.dp
    Box(Modifier.fillMaxWidth()) {
        CoverBackdrop(
            fan.middle?.coverURL,
            Modifier.matchParentSize().layout { measurable, constraints ->
                val top = 400.dp.roundToPx()
                val bottom = 170.dp.roundToPx()
                val placeable = measurable.measure(constraints.copy(minHeight = constraints.maxHeight + top + bottom, maxHeight = constraints.maxHeight + top + bottom))
                layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, -top) }
            },
            fadeHeight = 320.dp,
        )
        Column(
            Modifier.fillMaxWidth().statusBarsPadding().padding(top = 52.dp).padding(horizontal = 20.dp).padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.fillMaxWidth().height(coverWidth * 1.5f).padding(top = 8.dp), contentAlignment = Alignment.Center) {
                fan.leading?.let { Box(Modifier.offset(x = (-78).dp, y = 14.dp).rotate(-10f).scale(0.9f)) { Dimmed(it, coverWidth, 0.6f) } }
                fan.trailing?.let { Box(Modifier.offset(x = 78.dp, y = 14.dp).rotate(10f).scale(0.9f)) { Dimmed(it, coverWidth, 0.75f) } }
                fan.middle?.let { Box(Modifier.shadow(16.dp)) { BookCover(it, coverWidth, showsFormatBadge = false) } }
            }
            Column(Modifier.padding(top = 22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(name, style = Shiori.type.largeTitle.copy(fontWeight = FontWeight.Black), color = Color.White, textAlign = TextAlign.Center, maxLines = 3, overflow = TextOverflow.Ellipsis)
                Row(
                    Modifier.padding(top = 2.dp).then(if (onOpenAuthor != null) Modifier.plainClickable(onClick = onOpenAuthor) else Modifier),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(author, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium), color = Color.White, textAlign = TextAlign.Center, maxLines = 2)
                    if (onOpenAuthor != null) Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = Color.White.copy(alpha = 0.6f))
                }
                if (language != null && language.isForeign) Text(language.label, style = Shiori.type.caption, color = Color.White.copy(alpha = 0.75f))
            }
            Box(Modifier.padding(top = 16.dp)) { actions() }
        }
    }
}

@Composable
private fun Dimmed(book: Book, width: androidx.compose.ui.unit.Dp, darkness: Float) {
    Box {
        BookCover(book, width, showsFormatBadge = false)
        androidx.compose.foundation.Canvas(Modifier.matchParentSize()) { drawRect(Color.Black.copy(alpha = 1f - darkness)) }
    }
}
