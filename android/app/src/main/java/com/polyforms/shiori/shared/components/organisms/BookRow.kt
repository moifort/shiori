package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.components.atoms.AwaitedMark
import com.polyforms.shiori.shared.components.atoms.LanguageTag
import com.polyforms.shiori.shared.components.atoms.OpinionMark
import com.polyforms.shiori.shared.components.atoms.ReadingStatusBadge
import com.polyforms.shiori.shared.components.atoms.RowChip
import com.polyforms.shiori.shared.components.atoms.tint
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.color

/**
 * A book in a list: its cover at the height of its text, the title, the authors, the saga
 * chip and the genre chips, with the reader's marks at the top right.
 */
@Composable
fun BookRow(
    title: String,
    authorLine: String,
    cover: Book,
    status: ReadingStatus,
    rating: Double?,
    modifier: Modifier = Modifier,
    highlightedTitle: AnnotatedString? = null,
    ratingIsInherited: Boolean = false,
    volumeLabel: String? = null,
    publishedIn: Int? = null,
    series: SeriesMembership? = null,
    statusTag: ReadingStatus? = null,
    genre: BookGenre? = null,
    subgenre: String? = null,
    language: BookLanguage? = null,
    isFavorite: Boolean = false,
    genreInCorner: Boolean = false,
    isHidden: Boolean = false,
    isAwaited: Boolean = false,
    listeningProgress: String? = null,
    releaseDate: String? = null,
) {
    val colors = Shiori.colors
    val density = LocalDensity.current
    var textHeight by remember { mutableStateOf<Dp?>(null) }
    val shownRating = if (ratingIsInherited && status != ReadingStatus.READ) null else rating
    val shownStatusTag = if (statusTag == ReadingStatus.READ) null else statusTag

    @Composable
    fun titleText() {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                highlightedTitle ?: AnnotatedString(title),
                style = Shiori.type.body.copy(fontWeight = FontWeight.Medium),
                color = colors.label,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (language != null && language.isForeign) LanguageTag(language)
        }
    }

    @Composable
    fun marks() {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            if (isHidden) Icon(Symbol("eye.slash"), L("Non partagé"), Modifier.size(14.dp), tint = colors.secondaryLabel)
            if (isAwaited) AwaitedMark()
            OpinionMark(shownRating, isFavorite, 12.dp, ratingIsInherited)
            if (listeningProgress != null) RowChip(listeningProgress, ReadingStatus.READING.tint)
            if (shownStatusTag != null) {
                if (shownStatusTag == ReadingStatus.DROPPED) {
                    ReadingStatusBadge(ReadingStatus.DROPPED)
                } else {
                    RowChip(shownStatusTag.label, shownStatusTag.tint, shownStatusTag.symbol)
                }
            }
            if (genreInCorner && genre != null) RowChip(genre.label, genre.tint.color())
        }
    }

    Row(
        modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        BookCover(cover, minHeight = textHeight)
        Column(
            Modifier.weight(1f).onSizeChanged { textHeight = with(density) { it.height.toDp() } },
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    if (volumeLabel != null) {
                        Text(volumeLabel, style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold), color = colors.secondaryLabel)
                    } else {
                        titleText()
                    }
                }
                marks()
            }
            if (volumeLabel != null) titleText()
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                if (authorLine.isNotEmpty()) {
                    Text(
                        authorLine,
                        style = Shiori.type.subheadline,
                        color = colors.secondaryLabel,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                }
                if (publishedIn != null) {
                    Text(
                        if (authorLine.isEmpty()) "$publishedIn" else "· $publishedIn",
                        style = Shiori.type.subheadline,
                        color = colors.tertiaryLabel,
                    )
                }
            }
            if (series != null) {
                Row(Modifier.padding(top = 1.dp)) { RowChip("${series.name} · ${series.label}", colors.secondaryLabel) }
            }
            if ((genre != null && !genreInCorner) || subgenre != null) {
                Row(Modifier.padding(top = 1.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (genre != null && !genreInCorner) RowChip(genre.label, genre.tint.color())
                    if (subgenre != null) RowChip(subgenre, genre?.tint?.color() ?: colors.secondaryLabel)
                }
            }
        }
        if (releaseDate != null) {
            Spacer(Modifier.width(0.dp))
            ReleaseDateBadge(releaseDate)
        }
    }
}

/** A row drawn from a book, as every list draws its books. */
@Composable
fun BookRow(book: Book, modifier: Modifier = Modifier, statusTag: ReadingStatus? = null, genreInCorner: Boolean = false) =
    BookRow(
        title = book.title,
        authorLine = book.authorLine,
        cover = book,
        status = book.status,
        rating = book.shownRating,
        modifier = modifier,
        ratingIsInherited = book.ratingIsInherited,
        series = book.series,
        statusTag = statusTag,
        genre = book.genre,
        subgenre = book.subgenres.firstOrNull(),
        language = book.language,
        isFavorite = book.favorite,
        genreInCorner = genreInCorner,
        isHidden = book.hidden,
        listeningProgress = book.unfinishedListeningProgress?.let { "$it%" },
    )
