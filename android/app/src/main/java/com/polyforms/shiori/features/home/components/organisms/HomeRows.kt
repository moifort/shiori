package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.CoverEffect
import com.polyforms.shiori.shared.CoverEffectImage
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.WishContextMenuBox
import com.polyforms.shiori.shared.components.atoms.OutlinedTag
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.book.BookContextMenuBox
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.ProgressBar
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** One poster of a row: a book, its label, and where tapping it leads when not to the book. */
data class PosterRowItem(
    val book: Book,
    val label: PosterLabel,
    val open: (() -> Unit)? = null,
    /** "Retirer" on the long press, for a cover of the wishlist: what takes it off the list, when it is not the row's own. */
    val dropWished: (() -> Unit)? = null,
) {
    constructor(book: Book, caption: String, open: (() -> Unit)? = null, dropWished: (() -> Unit)? = null) : this(book, PosterLabel(caption), open, dropWished)

    val id: String get() = book.id
    val caption: String get() = label.caption
}

/** Posters in a horizontal row, or a grid of rows scrolling sideways; a long press opens the menu. */
@Composable
fun PosterRow(
    items: List<PosterRowItem>,
    modifier: Modifier = Modifier,
    coverWidth: Dp = 102.dp,
    rows: Int = 1,
    inset: Dp = 20.dp,
    onMenu: ((Book, BookQuickAction) -> Unit)? = null,
    /** The long press on a cover of the wishlist: "Retirer" alone. */
    onDropWished: ((Book) -> Unit)? = null,
    onOpen: (Book) -> Unit,
) {
    @Composable
    fun Poster(item: PosterRowItem) {
        val open = { item.open?.invoke() ?: onOpen(item.book) }
        val drop = item.dropWished ?: onDropWished?.let { drop -> { drop(item.book) } }
        val description = listOfNotNull(item.book.title, item.caption, item.label.cornerTag).joinToString(", ")
        if (drop != null) {
            WishContextMenuBox(open, drop, Modifier.semantics(mergeDescendants = true) { contentDescription = description }) {
                PosterCover(item.book, item.label, width = coverWidth)
            }
        } else {
            BookContextMenuBox(
                item.book,
                onOpen = open,
                onAction = onMenu?.let { menu -> { action: BookQuickAction -> menu(item.book, action) } },
                modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = description },
            ) {
                PosterCover(item.book, item.label, width = coverWidth)
            }
        }
    }
    if (rows > 1) {
        val height = coverWidth * 1.5f
        LazyHorizontalGrid(
            rows = GridCells.Fixed(rows),
            modifier = modifier.height(height * rows + 13.dp * (rows - 1)),
            contentPadding = PaddingValues(horizontal = inset),
            horizontalArrangement = Arrangement.spacedBy(13.dp),
            verticalArrangement = Arrangement.spacedBy(13.dp),
        ) {
            items(items, key = { it.id }) { Poster(it) }
        }
    } else {
        LazyRow(
            modifier,
            contentPadding = PaddingValues(horizontal = inset),
            horizontalArrangement = Arrangement.spacedBy(13.dp),
            verticalAlignment = Alignment.Top,
        ) {
            items(items, key = { it.id }) { Poster(it) }
        }
    }
}

/** One cover of a [CoverRow], with its caption and an optional tint for it. */
data class CoverRowItem(val book: Book, val caption: String, val captionTint: Color? = null) {
    val id: String get() = book.id
}

/** Small covers with a title and a caption under each, in a horizontal row. */
@Composable
fun CoverRow(items: List<CoverRowItem>, modifier: Modifier = Modifier, coverWidth: Dp = 76.dp, inset: Dp = 20.dp, onOpen: (Book) -> Unit) {
    val colors = Shiori.colors
    LazyRow(
        modifier,
        contentPadding = PaddingValues(horizontal = inset),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        items(items, key = { it.id }) { item ->
            Column(Modifier.plainClickable { onOpen(item.book) }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                BookCover(item.book, coverWidth, formatBadgeSize = 18.dp)
                Column(Modifier.width(coverWidth), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(
                        item.book.title,
                        style = Shiori.type.caption.copy(fontWeight = FontWeight.Medium),
                        color = colors.label,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        item.caption,
                        style = Shiori.type.caption2,
                        color = item.captionTint ?: colors.secondaryLabel,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
/** A saga as a card: its cover melted into a blur, its name and how far the reader got. */
@Composable
fun SeriesShowCard(
    series: Dashboard.SeriesProgress,
    modifier: Modifier = Modifier,
    tag: String? = null,
    isCompact: Boolean = false,
    isSetAside: Boolean = false,
    /**
     * The volume's day, `YYYY-MM-DD` or looser: a calendar leaf in the top corner, and over the
     * name "Audio" and how long is left when it is ahead; the tag then names the volume alone.
     */
    releaseDate: String? = null,
    onLongPress: (() -> Unit)? = null,
    onOpen: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    // Over the name, on one line from the left: "Audio" first for a saga heard, how long is left
    // before a volume ahead — a volume out says nothing of how long ago —, then a language other
    // than the phone's.
    val footTags = buildList {
        if (releaseDate == null) return@buildList
        if (series.isAudio) add(L("Audio"))
        ReleaseDateText.countdown(releaseDate)?.let(::add)
        series.language?.takeIf { it.isForeign }?.let { add(it.code) }
    }
    Box(
        modifier
            .heightIn(min = if (isCompact) 128.dp else 176.dp)
            .clip(shape)
            .border(1.dp, Color.White.copy(alpha = 0.22f), shape)
            .combinedClickable(interactionSource = null, indication = null, onLongClick = onLongPress, onClick = onOpen),
    ) {
        Box(Modifier.matchParentSize().alpha(if (isSetAside) 0.55f else 1f)) {
            Box(Modifier.fillMaxSize().background(Color(0xFF262626)))
            series.coverURL?.let { url ->
                CoverImage(url, Modifier.fillMaxSize())
                CoverEffectImage(
                    url,
                    CoverEffect.Melt(blur = if (isCompact) 16 else 20, fadeStart = 0.3, fadeEnd = 0.8, dimming = 0.0),
                    Modifier.fillMaxSize(),
                )
            }
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        *(0..10).map { step ->
                            val t = step / 10f
                            (0.4f + 0.6f * t) to Color.Black.copy(alpha = 0.3f * t * t * (3 - 2 * t))
                        }.toTypedArray(),
                    ),
                ),
            )
            if (isSetAside) Box(Modifier.fillMaxSize().background(Color.Gray.copy(alpha = 0.3f)))
        }
        Column(
            Modifier.matchParentSize().padding(if (isCompact) 10.dp else 12.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.Bottom),
        ) {
            if (footTags.isNotEmpty()) {
                Row(Modifier.padding(bottom = 3.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    footTags.forEach { OutlinedTag(it) }
                }
            }
            Text(
                series.name,
                style = if (isCompact) Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold) else Shiori.type.headline,
                color = Color.White,
                maxLines = if (isCompact) 2 else 1,
                overflow = TextOverflow.Ellipsis,
            )
            // No count where it is not known: a followed series seen from Actualité.
            if (series.totalCount > 0) Row(horizontalArrangement = Arrangement.spacedBy(if (isCompact) 6.dp else 8.dp), verticalAlignment = Alignment.CenterVertically) {
                val fraction = if (series.totalCount > 0) minOf(series.readCount, series.totalCount).toDouble() / series.totalCount else 0.0
                ProgressBar(fraction, if (isCompact) 24.dp else 40.dp)
                Text(
                    if (series.isAudio) {
                        L("%lld sur %lld écoutés", series.readCount, series.totalCount)
                    } else {
                        L("%lld sur %lld lus", series.readCount, series.totalCount)
                    },
                    style = if (isCompact) Shiori.type.caption2 else Shiori.type.caption,
                    color = Color.White.copy(alpha = 0.8f),
                    maxLines = 1,
                )
            }
        }
        if (tag != null) {
            Text(
                tag,
                style = Shiori.type.caption2.copy(fontWeight = FontWeight.Bold),
                color = Color.White,
                modifier = Modifier.align(Alignment.TopStart).padding(8.dp).glass(interactive = false).padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
        if (releaseDate != null) {
            Box(Modifier.align(Alignment.TopEnd).padding(8.dp)) { ReleaseDateBadge(releaseDate, onGlass = true) }
        } else {
            Box(Modifier.align(Alignment.TopEnd).padding(10.dp)) { CoverTags(series.language, series.isAudio) }
        }
    }
}

/** A spacer the width of a row's inset, for rows that scroll edge to edge. */
@Composable
fun RowInset(width: Dp = 20.dp) = Spacer(Modifier.size(width, 0.dp))

@Preview(showBackground = true)
@Composable
private fun HomeRowsPreview() = PreviewSurface {
    Column(Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PosterRow(
            DebugFixtures.reading.map {
                PosterRowItem(it, com.polyforms.shiori.shared.book.PosterLabel.of(it, com.polyforms.shiori.shared.book.PosterLabel.Context.RECENT))
            },
            onOpen = {},
        )
        CoverRow(DebugFixtures.toRead.map { CoverRowItem(it, it.authorLine) }, onOpen = {})
        SeriesShowCard(DebugFixtures.dashboard.series[0], Modifier.padding(horizontal = 16.dp)) {}
    }
}
