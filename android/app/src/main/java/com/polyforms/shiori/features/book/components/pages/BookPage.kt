package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.components.organisms.AwaitedEditionReleaseRow
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookFact
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.PersonDestination
import com.polyforms.shiori.shared.book.SeriesVolumesRow
import com.polyforms.shiori.shared.book.formatFactValue
import com.polyforms.shiori.shared.book.reading
import com.polyforms.shiori.shared.book.storeFactLinks
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.molecules.MessageBubble
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import java.time.Instant

/** The fields a date or number tile edits on its own. */
enum class BookField {
    FIRST_PUBLISHED_IN, PAGE_COUNT, ISBN13, ADDED_AT, STARTED_AT, FINISHED_AT;

    val title: String
        get() = when (this) {
            FIRST_PUBLISHED_IN -> L("Première parution")
            PAGE_COUNT -> L("Pages")
            ISBN13 -> L("ISBN")
            ADDED_AT -> L("Ajouté le")
            STARTED_AT -> L("Commencé le")
            FINISHED_AT -> L("Terminé le")
        }

    val isDate: Boolean get() = this == ADDED_AT || this == STARTED_AT || this == FINISHED_AT

    fun isEditable(book: Book): Boolean = when (this) {
        FIRST_PUBLISHED_IN, PAGE_COUNT, ISBN13 -> true
        ADDED_AT -> book.addedAt != null
        STARTED_AT -> book.startedAt != null
        FINISHED_AT -> book.finishedAt != null
    }

    val fact: BookFact?
        get() = when (this) {
            FIRST_PUBLISHED_IN -> BookFact.FIRST_PUBLISHED_IN
            PAGE_COUNT -> BookFact.PAGE_COUNT
            ISBN13 -> BookFact.ISBN13
            else -> null
        }
}

/** The next step a book's first button takes: start it, or mark it read. */
data class NextStep(val title: String, val symbol: String, val status: ReadingStatus) {
    companion object {
        fun of(status: ReadingStatus): NextStep? = when (status) {
            ReadingStatus.TO_READ -> NextStep(L("Commencer"), "book.fill", ReadingStatus.READING)
            ReadingStatus.READING -> NextStep(L("Marquer lu"), "checkmark", ReadingStatus.READ)
            else -> null
        }
    }
}

/** The reader's own book: its hero, synopsis, saga, facts, awaited editions and comments. */
@Composable
fun BookPage(
    book: Book,
    isSaving: Boolean,
    onSetStatus: (ReadingStatus) -> Unit,
    onRate: () -> Unit,
    onOpenSeries: () -> Unit,
    onEdit: () -> Unit,
    onEditGenre: () -> Unit,
    onEditRecommendation: () -> Unit,
    onEditNote: () -> Unit,
    onEditField: (BookField) -> Unit,
    modifier: Modifier = Modifier,
    onOpenProgress: () -> Unit = {},
    seriesVolumes: List<SeriesStripItem> = emptyList(),
    onOpenVolume: (Book) -> Unit = {},
    onOpenAuthor: ((PersonDestination) -> Unit)? = null,
    onOpenNarrator: ((PersonDestination) -> Unit)? = null,
    awaited: List<AwaitedEdition> = emptyList(),
    onOpenAwaited: (AwaitedEdition) -> Unit = {},
    onStopAwaiting: (AwaitedEdition) -> Unit = {},
    isComposingNote: Boolean = false,
    contentPadding: PaddingValues = PaddingValues(),
) {
    val scroll = rememberScrollState()
    val haptics = LocalHapticFeedback.current
    var revealNote by remember { mutableStateOf(0) }
    LaunchedEffect(book.status) { haptics.performHapticFeedback(HapticFeedbackType.Confirm) }
    LaunchedEffect(revealNote, book.note, book.recommendation, isComposingNote) {
        if (revealNote > 0 || isComposingNote) scroll.animateScrollTo(scroll.maxValue)
    }
    Column(
        modifier
            .fillMaxSize()
            .background(Shiori.colors.groupedBackground)
            .verticalScroll(scroll, enabled = !isSaving)
            .padding(contentPadding),
    ) {
        BookHero(
            book,
            state = if (book.status == ReadingStatus.DROPPED) null else BookState.reading(book),
            isAwaited = awaited.isNotEmpty(),
            onOpenAuthor = onOpenAuthor,
            onOpenNarrator = onOpenNarrator,
            onOpenProgress = onOpenProgress,
        ) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val statusEntries = (ReadingStatus.progression + ReadingStatus.DROPPED).map { status ->
                    MenuEntry.Item(status.label, status.symbol, checked = status == book.status) { onSetStatus(status) }
                }
                val step = NextStep.of(book.status)
                when {
                    book.tracksPages -> HeroButton(L("Progression"), "bookmark.fill", prominent = true, menu = statusEntries, onClick = onOpenProgress)
                    step != null -> HeroButton(step.title, step.symbol, prominent = true, menu = statusEntries) { onSetStatus(step.status) }
                    else -> HeroButton(book.status.label, book.status.symbol, prominent = true, menu = statusEntries, menuOnTap = true) {}
                }
                val rating = book.rating
                if (rating != null) {
                    HeroButton(null, null, content = { RatingStars(rating, size = 13.dp, monochrome = true, tint = Color.White) }, onClick = onRate)
                } else {
                    HeroButton(L("Noter"), "star", onClick = onRate)
                }
                HeroButton(L("Remarques"), "text.bubble") {
                    if (book.note == null) onEditNote() else revealNote++
                }
            }
        }
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            book.synopsis?.let { BookSynopsisBlock(it) }
            book.series?.let { membership ->
                SeriesVolumesRow(
                    membership.name,
                    if (seriesVolumes.isEmpty()) listOf(SeriesStripItem.Owned(book)) else seriesVolumes,
                    book.id,
                    onOpenSeries,
                    onOpenVolume,
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Informations"), detail = L("modifier"), action = onEdit)
                FactGrid(listOf(FactGroup(dayTiles(book, onEditField), 3), FactGroup(factTiles(book, onEdit, onEditGenre, onEditField))), book.storeFactLinks)
            }
            val found = awaited.filter { it.state != AwaitedState.UNANNOUNCED }
            if (found.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Éditions guettées"))
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Shiori.colors.secondaryGroupedBackground)) {
                        found.forEachIndexed { index, edition ->
                            var menu by remember { mutableStateOf(false) }
                            Box {
                                @OptIn(ExperimentalFoundationApi::class)
                                Box(
                                    Modifier
                                        .combinedClickable(onClick = { onOpenAwaited(edition) }, onLongClick = { menu = true })
                                        .padding(horizontal = 14.dp, vertical = 10.dp),
                                ) { AwaitedEditionReleaseRow(edition) }
                                MenuEntries(
                                    listOf(MenuEntry.Item(L("Ne plus suivre"), "bell.slash", destructive = true) { onStopAwaiting(edition) }),
                                    menu,
                                ) { menu = false }
                            }
                            if (index < found.lastIndex) ShioriDivider(Modifier.padding(start = 14.dp))
                        }
                    }
                }
            }
            if (book.recommendation != null || book.note != null) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Commentaires"))
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        book.recommendation?.let { recommendation ->
                            MessageBubble(
                                recommendation.comment ?: L("Je te le conseille."),
                                sender = recommendation.recommenderName ?: L("Conseillé"),
                                action = onEditRecommendation,
                            )
                        }
                        book.note?.let { note ->
                            Box(Modifier.alpha(if (isComposingNote) 0.4f else 1f)) { MessageBubble(note, isMine = true, action = onEditNote) }
                        }
                    }
                }
            }
        }
    }
}

private fun dayTiles(book: Book, onEditField: (BookField) -> Unit): List<FactTile> {
    fun day(date: Instant?) = date?.let { DateText.dayMonthShort(DateText.local(it)) }
    fun edit(field: BookField): (() -> Unit)? = if (field.isEditable(book)) ({ onEditField(field) }) else null
    return listOf(
        FactTile("addedAt", L("Ajouté"), day(book.addedAt), placeholder = "—", action = edit(BookField.ADDED_AT)),
        FactTile("startedAt", L("Commencé"), day(book.startedAt), placeholder = "—", action = edit(BookField.STARTED_AT)),
        FactTile("finishedAt", L("Terminé"), day(book.finishedAt), placeholder = "—", action = edit(BookField.FINISHED_AT)),
    )
}

private fun factTiles(book: Book, onEdit: () -> Unit, onEditGenre: () -> Unit, onEditField: (BookField) -> Unit): List<FactTile> = buildList {
    add(FactTile("genre", L("Genre"), book.genre?.label, chips = book.subgenres, isWide = true, showsChevron = true, action = onEditGenre))
    add(FactTile("format", L("Format"), book.formatFactValue, action = onEdit))
    add(FactTile("publisher", L("Éditeur"), book.publisher, action = onEdit))
    add(FactTile("firstPublishedIn", L("Parution"), book.firstPublishedIn?.toString(), action = { onEditField(BookField.FIRST_PUBLISHED_IN) }))
    val duration = book.durationLabel
    if (duration != null) {
        add(FactTile("duration", L("Durée"), duration))
    } else {
        add(FactTile("pageCount", L("Pages"), book.pageCount?.toString(), action = { onEditField(BookField.PAGE_COUNT) }))
    }
    val year = book.editionYear
    if (BookFact.EDITION_YEAR.applies(book) && year != null) add(FactTile("editionYear", L("Année d'édition"), year.toString(), action = onEdit))
    if (book.format != BookFormat.AUDIOBOOK) add(FactTile("isbn13", L("ISBN"), book.isbn13, monospaced = true, action = { onEditField(BookField.ISBN13) }))
}

/**
 * A hero button: a glass capsule, white and prominent for the first one. A menu opens on a long
 * press, as a SwiftUI `Menu` with a primary action does, or on the tap when it has no action.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HeroButton(
    title: String?,
    symbol: String?,
    prominent: Boolean = false,
    menu: List<MenuEntry> = emptyList(),
    menuOnTap: Boolean = false,
    content: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val foreground = if (prominent) Color.Black else Color.White
    Box {
        Row(
            Modifier
                .height(40.dp)
                .clip(CircleShape)
                .then(if (prominent) Modifier.background(Color.White, CircleShape) else Modifier.background(Color.White.copy(alpha = 0.18f), CircleShape))
                .combinedClickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = { if (menuOnTap) expanded = true else onClick() },
                    onLongClick = if (menu.isNotEmpty()) ({ expanded = true }) else null,
                )
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (content != null) {
                content()
            } else {
                if (symbol != null) Icon(Symbol(symbol), null, Modifier.size(18.dp), tint = foreground)
                if (title != null) Text(title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = foreground, maxLines = 1)
            }
        }
        if (menu.isNotEmpty()) MenuEntries(menu, expanded) { expanded = false }
    }
}

