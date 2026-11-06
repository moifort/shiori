package com.polyforms.shiori.shared.book

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.OutlinedTag
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.coverGround
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * The head of every book page: the cover beside the saga, title, author and state, on a wash of
 * the cover, and the page's buttons under it. Always drawn light on dark, whatever the scheme.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BookHero(
    book: Book,
    modifier: Modifier = Modifier,
    state: BookState? = null,
    isAwaited: Boolean = false,
    showsLength: Boolean = true,
    onOpenAuthor: ((PersonDestination) -> Unit)? = null,
    onOpenNarrator: ((PersonDestination) -> Unit)? = null,
    coverWidth: Dp = 108.dp,
    releaseDate: String? = null,
    countdown: String? = null,
    onOpenProgress: (() -> Unit)? = null,
    overTitle: (@Composable () -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    val dark = Shiori.colors.isDark
    Box(modifier.fillMaxWidth()) {
        // The wash reaches up under the status bar and down past the hero, into the page.
        CoverBackdrop(
            book.coverURL,
            Modifier.matchParentSize().layout { measurable, constraints ->
                val extraTop = 400.dp.roundToPx()
                val extraBottom = 170.dp.roundToPx()
                val placeable = measurable.measure(constraints.copy(minHeight = constraints.maxHeight + extraTop + extraBottom, maxHeight = constraints.maxHeight + extraTop + extraBottom))
                layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, -extraTop) }
            },
            fadeHeight = 320.dp,
            tint = book.coverGround(dark),
        )
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(Modifier.fillMaxWidth()) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.Bottom) {
                    Box(Modifier.shadow(16.dp, ambientColor = Color.Black.copy(alpha = 0.45f))) {
                        BookCover(book, coverWidth, showsFormatBadge = false)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        if (overTitle != null) Box(Modifier.padding(bottom = 6.dp)) { overTitle() }
                        book.series?.let { series ->
                            Text(
                                listOfNotNull(series.name, series.volume?.let { "· ${L("Tome %lld", it)}" }).joinToString(" "),
                                style = Shiori.type.subheadline,
                                color = Color.White.copy(alpha = 0.8f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(end = if (releaseDate != null) 58.dp else 0.dp),
                            )
                        }
                        Text(
                            book.title,
                            style = Shiori.type.title2,
                            color = Color.White,
                            maxLines = 4,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(end = if (releaseDate != null) 58.dp else 0.dp),
                        )
                        PersonLine(book.authorLine, book.authorDestinations, "author", Shiori.type.subheadline, 0.85f, onOpenAuthor)
                        book.narratorLine?.let { line ->
                            PersonLine(L("Lu par %@", line), book.narratorDestinations, "music.mic", Shiori.type.caption, 0.7f, onOpenNarrator)
                        }
                        Column(Modifier.padding(top = 5.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            val details = buildList {
                                state?.let { add(it.text) }
                                if (showsLength) {
                                    val duration = book.durationLabel
                                    if (duration != null) add(duration) else book.pageCount?.let { add(L("%lld pages", it)) }
                                }
                            }.joinToString(" · ")
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                if (details.isNotEmpty()) {
                                    Text(details, style = Shiori.type.caption, color = Color.White.copy(alpha = 0.75f), maxLines = 2)
                                }
                                CoverTags(book, isFrosted = false)
                                if (countdown != null) OutlinedTag(countdown, isFrosted = false)
                            }
                            book.unfinishedListeningProgress?.let { ListeningProgressLine(it, book.durationMinutes) }
                            ReadingPageLine(book.unfinishedReadingPage, book.pageCount, onOpenProgress)
                        }
                    }
                }
                Row(Modifier.align(Alignment.TopEnd), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (book.hidden) Icon(Symbol("eye.slash"), L("Non partagé"), Modifier.size(20.dp), tint = Color.White.copy(alpha = 0.7f))
                    if (isAwaited) Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(20.dp), tint = Color.White.copy(alpha = 0.7f))
                    if (releaseDate != null) ReleaseDateBadge(releaseDate, onGlass = true)
                }
            }
            actions()
        }
    }
}

/** An author or narrator line that opens their page; a menu when the book names several. */
@Composable
private fun PersonLine(
    text: String,
    people: List<PersonDestination>,
    symbol: String,
    style: androidx.compose.ui.text.TextStyle,
    alpha: Float,
    onOpen: ((PersonDestination) -> Unit)?,
) {
    var menu by remember { mutableStateOf(false) }
    val first = people.firstOrNull()
    Box {
        Row(
            Modifier.then(
                if (onOpen != null && first != null) {
                    Modifier.plainClickable { if (people.size == 1) onOpen(first) else menu = true }
                } else {
                    Modifier
                },
            ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(text, style = style, color = Color.White.copy(alpha = alpha), maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            if (onOpen != null && first != null) {
                Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = Color.White.copy(alpha = alpha - 0.25f))
            }
        }
        DropdownMenu(menu, { menu = false }) {
            people.forEach { person ->
                DropdownMenuItem(
                    text = { Text(person.name) },
                    leadingIcon = { Icon(Symbol(symbol), null) },
                    onClick = {
                        menu = false
                        onOpen?.invoke(person)
                    },
                )
            }
        }
    }
}

