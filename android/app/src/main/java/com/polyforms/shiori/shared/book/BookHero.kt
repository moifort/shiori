package com.polyforms.shiori.shared.book

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.getValue
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.components.atoms.HeroStatus
import com.polyforms.shiori.shared.components.atoms.StatusPill
import com.polyforms.shiori.shared.components.atoms.coverTagsAreEmpty
import com.polyforms.shiori.shared.components.atoms.setAsideAnimation
import com.polyforms.shiori.shared.components.styles.saturation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
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
    /** Where the edition stands, as a word in an outlined tag on the detail line: "Pas annoncé". */
    stateTag: String? = null,
    /** The reader awaits an edition of it: "Guetté" joins the tags. */
    isAwaited: Boolean = false,
    showsLength: Boolean = true,
    onOpenAuthor: ((PersonDestination) -> Unit)? = null,
    onOpenNarrator: ((PersonDestination) -> Unit)? = null,
    coverWidth: Dp = 108.dp,
    releaseDate: String? = null,
    countdown: String? = null,
    onOpenProgress: (() -> Unit)? = null,
    overTitle: (@Composable () -> Unit)? = null,
    /** What the reader decided of it, in words under the detail line: "Pas intéressé". */
    status: HeroStatus? = null,
    /** Turned down by the reader: the cover and its colours turn black and white. */
    isSetAside: Boolean = false,
    /** An Audible title kept on the phone: "Téléchargé" joins the tags. */
    isDownloaded: Boolean = false,
    /** Whose book it is, when it is a friend's: their name on a pill level with the cover's top. */
    owner: (@Composable () -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    val saturation by animateFloatAsState(if (isSetAside) 0f else 1f, setAsideAnimation(), label = "setAside")
    val dark = Shiori.colors.isDark
    Box(modifier.fillMaxWidth()) {
        // The wash reaches up under the status bar and down past the hero, into the page.
        CoverBackdrop(
            book.coverURL,
            Modifier.matchParentSize().saturation(saturation).layout { measurable, constraints ->
                val extraTop = 400.dp.roundToPx()
                val extraBottom = 170.dp.roundToPx()
                val placeable = measurable.measure(constraints.copy(minHeight = constraints.maxHeight + extraTop + extraBottom, maxHeight = constraints.maxHeight + extraTop + extraBottom))
                layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, -extraTop) }
            },
            fadeHeight = 320.dp,
            tint = book.coverGround(dark),
        )
        Column(
            // Under the floating bar: the status bar, then the bar's own height.
            Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 12.dp + 52.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Box(Modifier.fillMaxWidth()) {
                Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.Bottom) {
                    Box(Modifier.shadow(16.dp, ambientColor = Color.Black.copy(alpha = 0.45f)).saturation(saturation)) {
                        // No format badge: the outlined tags over the saga say it.
                        BookCover(book, coverWidth, showsFormatBadge = false)
                    }
                    Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.Bottom)) {
                        if (owner != null) {
                            // Level with the cover's top while the text leaves room.
                            owner()
                            Spacer(Modifier.weight(1f).heightIn(min = 10.dp))
                        }
                        if (overTitle != null) Box(Modifier.padding(bottom = 6.dp)) { overTitle() }
                        HeroTags(book, isDownloaded, isAwaited, Modifier.padding(end = if (releaseDate != null) 58.dp else 0.dp, bottom = 3.dp))
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
                                if (stateTag != null) OutlinedTag(stateTag, isFrosted = false)
                                if (countdown != null) OutlinedTag(countdown, isFrosted = false)
                            }
                            book.unfinishedListeningProgress?.let { ListeningProgressLine(it, book.durationMinutes) }
                            ReadingPageLine(book.unfinishedReadingPage, book.pageCount, onOpenProgress)
                        }
                        if (status != null) StatusPill(status.text, status.symbol, Modifier.padding(top = 8.dp))
                    }
                }
                // In the corner over the text, level with the cover's top: the day a book to come is out.
                if (releaseDate != null) {
                    Box(Modifier.align(Alignment.TopEnd)) { ReleaseDateBadge(releaseDate, onGlass = true) }
                }
            }
            actions()
        }
    }
}

/**
 * What the edition is, in outlined tags over the saga: only a foreign edition and a recording are
 * tagged, and a recording kept on the phone. Then what the reader decided of it, a symbol before
 * the word: kept out of the shared libraries, an edition awaited. Words only, never a button.
 */
@Composable
private fun HeroTags(book: Book, isDownloaded: Boolean, isAwaited: Boolean, modifier: Modifier = Modifier) {
    val coverEmpty = coverTagsAreEmpty(book.language, book.format == BookFormat.AUDIOBOOK)
    if (coverEmpty && !isDownloaded && !book.hidden && !isAwaited) return
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (!coverEmpty) CoverTags(book, isFrosted = false)
        if (isDownloaded) OutlinedTag(L("Téléchargé"), isFrosted = false, trailingSymbol = "arrow.down")
        if (book.hidden) OutlinedTag(L("Non partagé"), isFrosted = false, symbol = "eye.slash")
        if (isAwaited) OutlinedTag(L("Guetté"), isFrosted = false, symbol = "binoculars.fill")
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

