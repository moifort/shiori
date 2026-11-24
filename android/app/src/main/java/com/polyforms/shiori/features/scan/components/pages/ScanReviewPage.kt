package com.polyforms.shiori.features.scan.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.book.SeriesPlacement
import com.polyforms.shiori.features.book.components.pages.BookField
import com.polyforms.shiori.features.book.components.pages.FieldEditSheet
import com.polyforms.shiori.features.book.components.pages.GenreEditSheet
import com.polyforms.shiori.features.book.components.pages.HeroButton
import com.polyforms.shiori.features.book.components.pages.SeriesJoinSheet
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.MediaToggles
import com.polyforms.shiori.shared.book.SeriesVolumesRow
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/*
 * What the model proposed, before anything is saved, drawn as the book's page draws a book: the
 * hero over the cover's colours, then the summary, the saga and the facts as tiles. Every fact is
 * a guess — the safety net against a misread cover — so every one can be corrected: the
 * publisher, the year, the pages and the ISBN from their tile, every tile shown even when the
 * cover said nothing; the title and author from the facts' header, the saga and the genre from
 * their sheets; the edition's language from its tile, presumed the app's own. Nothing leaves the
 * phone until the reader adds it.
 *
 * Where the book goes is the hero's to say: "Ajouter" puts it on the pile on a tap and offers
 * "En cours" and "Déjà lu" on a long press, each asking for its day; "Envie" puts it on the
 * wishlist; "Guetter", when its edition in the app's language may be awaited, awaits it instead.
 * The "+" of the bar offers all of it again, within reach once the hero has scrolled away.
 */

/** Everything the review can ask for. */
sealed interface ScanReviewAction {
    /** The draft, and the saga as the reader renamed it, if they did. */
    data class Save(val draft: BookDraft, val series: SeriesPlacement?) : ScanReviewAction
    data object Retake : ScanReviewAction
    /** The edition in the app's language awaited instead of the book added: the scan is then over. */
    data class AwaitEdition(val draft: BookDraft, val format: ReleaseFormat) : ScanReviewAction
    /** Onto the wishlist rather than the shelf: the scan is then over. */
    data class Wish(val draft: BookDraft) : ScanReviewAction
    /** The language or the format was corrected: what may be awaited, and the saga, are asked again. */
    data class LanguageOrFormatChanged(val language: BookLanguage?, val format: BookFormat) : ScanReviewAction
    data class OpenOwnedCopy(val book: Book) : ScanReviewAction
}

private enum class ReviewSheet { IDENTITY, SERIES, GENRE }

/** The draft as the book's page would draw it once saved. */
private fun BookDraft.asReviewedBook(renamed: SeriesPlacement?): Book = Book(
    id = "review",
    title = title,
    authors = authors,
    format = format,
    media = if (format == BookFormat.AUDIOBOOK) emptyList() else media,
    publisher = publisher,
    firstPublishedIn = firstPublishedIn,
    synopsis = synopsis,
    genre = genre,
    subgenres = subgenres,
    pageCount = pageCount,
    isbn13 = isbn13,
    language = language,
    series = renamed?.let { SeriesMembership("", it.name, it.volume, VolumeKind.MAIN) } ?: series,
    coverURL = coverURL,
    status = status,
)

private fun <T> Change<T>?.valueOr(old: T?): T? = when (this) {
    null -> old
    is Change.Set -> value
    Change.Clear -> null
}

/** A correction read back into the draft. The saga is never part of one: it stays as the scan resolved it. */
fun BookDraft.applying(correction: BookCorrection): BookDraft = copy(
    title = correction.title ?: title,
    authors = correction.authors ?: authors,
    format = correction.format ?: format,
    media = correction.media ?: media,
    publisher = correction.publisher.valueOr(publisher),
    firstPublishedIn = correction.firstPublishedIn.valueOr(firstPublishedIn),
    synopsis = correction.synopsis.valueOr(synopsis),
    genre = correction.genre.valueOr(genre),
    subgenres = correction.subgenres ?: subgenres,
    pageCount = correction.pageCount.valueOr(pageCount),
    isbn13 = correction.isbn13.valueOr(isbn13),
    language = correction.language.valueOr(language),
)

/**
 * The saga's row with the book scanned in its own place, bright and ringed: in place of the volume
 * the reader lacks, or of their own copy of it. The book alone when the saga was renamed here, or
 * before its volumes have loaded.
 */
internal fun reviewRowVolumes(book: Book, sagaVolumes: List<SeriesStripItem>, renamed: Boolean): List<SeriesStripItem> {
    val current = SeriesStripItem.Owned(book)
    val number = book.series?.volume
    if (renamed || number == null || sagaVolumes.isEmpty()) return listOf(current)
    var placed = false
    val items = sagaVolumes.mapNotNull { item ->
        val isThisVolume = when (item) {
            is SeriesStripItem.Missing -> item.number == number
            is SeriesStripItem.Owned -> item.book.series?.kind == VolumeKind.MAIN && item.book.series?.volume == number
        }
        if (!isThisVolume) return@mapNotNull item
        if (placed) null else current.also { placed = true }
    }
    return if (placed) items else items + current
}

/** What the AI read off the cover, drawn as the book's page, to check and correct before the book is added. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanReviewPage(
    initial: BookDraft,
    ownedCopy: Book?,
    isSaving: Boolean,
    awaitable: List<ReleaseFormat>,
    loadSubgenres: suspend () -> List<String>,
    loadVocabulary: suspend () -> BookVocabulary?,
    /** The saga's volumes, held or lacking, as the book's page will list them. */
    sagaVolumes: List<SeriesStripItem> = emptyList(),
    /** Closes the scan, beside "Reprendre". */
    onClose: (() -> Unit)? = null,
    onAction: suspend (ScanReviewAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(initial) }
    var renamed by remember { mutableStateOf<SeriesPlacement?>(null) }
    var sheet by remember { mutableStateOf<ReviewSheet?>(null) }
    var editedField by remember { mutableStateOf<BookField?>(null) }
    var choosesLanguage by remember { mutableStateOf(false) }
    var addMenu by remember { mutableStateOf(false) }
    // The status the book is being added as, while its day is asked.
    var askedDate by remember { mutableStateOf<ReadingStatus?>(null) }
    val book = draft.asReviewedBook(renamed)
    val colors = Shiori.colors
    fun send(action: ScanReviewAction) {
        scope.launch { onAction(action) }
    }
    LaunchedEffect(draft.language, draft.format) { onAction(ScanReviewAction.LanguageOrFormatChanged(draft.language, draft.format)) }

    val canSave = draft.title.isNotBlank() && !isSaving
    // Saves the book in the status picked, with the day the reader gave it: the start of a book
    // under way, the finish of one read — the server stamps the start of a read book on its finish.
    fun save(status: ReadingStatus, day: Instant?) {
        val approved = draft.copy(
            status = status,
            rating = 0.0,
            favorite = false,
            startedAt = if (status == ReadingStatus.READING) day else null,
            finishedAt = if (status == ReadingStatus.READ) day else null,
        )
        send(ScanReviewAction.Save(approved, renamed))
    }
    // On the pile at once; under way or read once its day is picked.
    fun add(status: ReadingStatus) {
        if (!canSave) return
        if (status == ReadingStatus.TO_READ) save(status, null) else askedDate = status
    }
    fun wish() {
        if (canSave) send(ScanReviewAction.Wish(draft))
    }
    fun awaitEdition(format: ReleaseFormat) = send(ScanReviewAction.AwaitEdition(draft, format))

    // The three ways onto the shelf, in the order a book goes through them.
    val shelfChoices = listOf(
        MenuEntry.Item(L("À lire"), ReadingStatus.TO_READ.symbol) { add(ReadingStatus.TO_READ) },
        MenuEntry.Item(L("En cours"), ReadingStatus.READING.symbol) { add(ReadingStatus.READING) },
        MenuEntry.Item(L("Déjà lu"), ReadingStatus.READ.symbol) { add(ReadingStatus.READ) },
    )
    val awaitChoices = awaitable.map { format ->
        MenuEntry.Item(format.awaitLabel, if (format == ReleaseFormat.AUDIOBOOK) "headphones" else "binoculars") { awaitEdition(format) }
    }

    Box(Modifier.fillMaxSize().background(colors.groupedBackground)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState(), enabled = !isSaving)) {
            BookHero(book) {
                // "Ajouter" white, as the book's page sets its next step, "Envie" and "Guetter" on
                // glass beside it; sideways past the width rather than a label cut.
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HeroButton(L("Ajouter"), "plus", prominent = true, menu = shelfChoices, showsMenu = true) { add(ReadingStatus.TO_READ) }
                    HeroButton(L("Envie"), "bookmark") { wish() }
                    if (awaitable.isNotEmpty()) {
                        if (awaitable.size > 1) {
                            HeroButton(L("Guetter"), "binoculars", menu = awaitChoices, menuOnTap = true, showsMenu = true) {}
                        } else {
                            HeroButton(L("Guetter"), "binoculars") { awaitEdition(awaitable.first()) }
                        }
                    }
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                if (ownedCopy != null) {
                    OwnedCopyBlock(ownedCopy, mediaJoining(draft, ownedCopy)) { send(ScanReviewAction.OpenOwnedCopy(ownedCopy)) }
                }
                draft.synopsis?.let { BookSynopsisBlock(it) }
                book.series?.let { membership ->
                    SeriesVolumesRow(
                        membership.name,
                        reviewRowVolumes(book, sagaVolumes, renamed != null),
                        book.id,
                        onOpenSeries = { sheet = ReviewSheet.SERIES },
                        onOpenVolume = {},
                    )
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Informations"), detail = L("titre et auteur"), action = { sheet = ReviewSheet.IDENTITY })
                    Box {
                        FactGrid(listOf(FactGroup(factTiles(book, draft, { sheet = it }, { editedField = it }, { choosesLanguage = true }))))
                        val choices = BookLanguage.reviewChoices.let { list -> draft.language?.takeIf { it !in list }?.let { list + it } ?: list }
                        MenuEntries(
                            choices.map { language -> MenuEntry.Item(language.label, checked = language == draft.language) { draft = draft.copy(language = language) } },
                            choosesLanguage,
                        ) { choosesLanguage = false }
                    }
                }
            }
        }
        // The bar: "Reprendre" leading, the title, the "+" that offers everything the hero does.
        Row(
            Modifier.statusBarsPadding().fillMaxWidth().height(56.dp).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            onClose?.let { close -> ToolbarIconButton(L("Fermer"), "xmark", onClick = close) }
            ToolbarIconButton(L("Reprendre"), "arrow.counterclockwise") { send(ScanReviewAction.Retake) }
            Text(L("Vérifier"), style = Shiori.type.headline, color = colors.label, textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.weight(1f))
            Box {
                ToolbarIconButton(L("Ajouter"), "plus", prominent = true, enabled = !isSaving) { addMenu = true }
                MenuEntries(
                    buildList {
                        addAll(shelfChoices)
                        add(MenuEntry.Divider)
                        add(MenuEntry.Item(L("Liste d'envies"), "bookmark") { wish() })
                        if (awaitChoices.isNotEmpty()) {
                            add(MenuEntry.Divider)
                            addAll(awaitChoices)
                        }
                    },
                    addMenu,
                ) { addMenu = false }
            }
        }
    }

    val dismiss = { sheet = null }
    when (sheet) {
        ReviewSheet.IDENTITY -> ScanIdentitySheet(book, dismiss) { draft = draft.applying(it) }
        ReviewSheet.GENRE -> GenreEditSheet(book, loadSubgenres, dismiss) { correction ->
            draft = draft.applying(correction)
            null
        }
        ReviewSheet.SERIES -> SeriesJoinSheet(book, loadVocabulary, dismiss) { correction ->
            (correction.series as? Change.Set)?.let { renamed = it.value }
            null
        }
        null -> Unit
    }
    editedField?.let { field ->
        FieldEditSheet(book, field, { editedField = null }) { correction ->
            draft = draft.applying(correction)
            null
        }
    }
    askedDate?.let { status ->
        ReadingDateDialog(if (status == ReadingStatus.READ) L("Terminé le") else L("Commencé le"), onDismiss = { askedDate = null }) { day ->
            askedDate = null
            save(status, day)
        }
    }
}

/** What the cover said, as the book's page tiles it, every tile there to be corrected. */
private fun factTiles(
    book: Book,
    draft: BookDraft,
    onSheet: (ReviewSheet) -> Unit,
    onField: (BookField) -> Unit,
    onLanguage: () -> Unit,
): List<FactTile> = buildList {
    add(FactTile("genre", L("Genre"), book.genre?.label, chips = book.subgenres, isWide = true, showsChevron = true, action = { onSheet(ReviewSheet.GENRE) }))
    // A saga read off the cover heads its own row; none, and it is joined from here.
    if (book.series == null) {
        add(FactTile("series", L("Série"), null, isWide = true, placeholder = L("Aucune"), showsChevron = true, action = { onSheet(ReviewSheet.SERIES) }))
    }
    add(FactTile("format", L("Format"), formatValue(book)))
    add(FactTile("publisher", L("Éditeur"), book.publisher, action = { onField(BookField.PUBLISHER) }))
    add(FactTile("firstPublishedIn", L("Parution"), book.firstPublishedIn?.toString(), action = { onField(BookField.FIRST_PUBLISHED_IN) }))
    add(FactTile("pageCount", L("Pages"), book.pageCount?.toString(), action = { onField(BookField.PAGE_COUNT) }))
    if (book.format != BookFormat.AUDIOBOOK) add(FactTile("isbn13", L("ISBN"), book.isbn13, monospaced = true, action = { onField(BookField.ISBN13) }))
    // The edition decides which volumes of its saga are out. Presumed in the app's language, switched here.
    add(FactTile("language", L("Langue"), draft.language?.label, placeholder = L("Non renseignée"), showsChevron = true, chevronSymbol = "chevron.up.chevron.down", action = onLanguage))
}

/** What the book is and how the reader holds it, as the book's page says it: "Livre · papier". */
private fun formatValue(book: Book): String =
    if (book.format == BookFormat.AUDIOBOOK || book.media.isEmpty()) book.format.label
    else "${book.format.label} · ${BookMedium.label(book.media).lowercase()}"

/**
 * The media this book brings to the copy the reader already keeps, which it then joins rather than
 * doubles. Empty when it brings none, and saving shelves a second copy.
 */
private fun mediaJoining(draft: BookDraft, copy: Book): List<BookMedium> {
    if (draft.format == BookFormat.AUDIOBOOK || copy.format == BookFormat.AUDIOBOOK) return emptyList()
    val language = draft.language
    val held = copy.language
    if (language != null && held != null && language != held) return emptyList()
    return draft.media.filter { it !in copy.media }
}

/**
 * The reader already keeps this book, opening their copy: a warning when saving would shelve a
 * second one, a note when it joins the copy on another medium.
 */
@Composable
private fun OwnedCopyBlock(copy: Book, joining: List<BookMedium>, onOpen: () -> Unit) {
    val colors = Shiori.colors
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.secondaryGroupedBackground).plainClickable(onClick = onOpen).padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Symbol(if (joining.isEmpty()) "exclamationmark.triangle.fill" else "link"), null, Modifier.size(20.dp), tint = colors.label)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(L("Déjà dans votre bibliothèque"), style = Shiori.type.headline, color = colors.label)
            Text("${copy.title} · ${copy.status.label}", style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
            Text(
                if (joining.isEmpty()) L("Vous pouvez l'ajouter une seconde fois, pour une autre édition par exemple.")
                else L("Il rejoindra votre fiche, désormais en %@. Un seul livre, quel que soit le support.", BookMedium.label(copy.media + joining)),
                style = Shiori.type.footnote,
                color = colors.secondaryLabel,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
    }
}

/**
 * Asked when a book being checked is added "En cours" or "Déjà lu": the day it was started, or
 * finished, on a calendar opened on today. Closed without an answer, the book is not added.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReadingDateDialog(title: String, onDismiss: () -> Unit, onPick: (Instant) -> Unit) {
    val colors = Shiori.colors
    val now = Instant.now()
    val state = rememberDatePickerState(
        initialSelectedDateMillis = now.atZone(ZoneId.systemDefault()).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= now.toEpochMilli() + 86_400_000
        },
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val millis = state.selectedDateMillis ?: return@TextButton
                val day = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                onPick(minOf(day.atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), now))
            }) { Text(L("Enregistrer"), color = colors.accent) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(L("Annuler"), color = colors.accent) } },
    ) {
        Text(title, style = Shiori.type.headline, color = colors.label, modifier = Modifier.padding(start = 24.dp, top = 16.dp))
        DatePicker(state, showModeToggle = false, title = null, headline = null)
    }
}

/** The title, authors, format and media of a scanned book, corrected by hand. */
@Composable
fun ScanIdentitySheet(book: Book, onDismiss: () -> Unit, onSave: (BookCorrection) -> Unit) {
    var title by remember { mutableStateOf(book.title) }
    var authors by remember { mutableStateOf(book.authors.joinToString(", ")) }
    var format by remember { mutableStateOf(book.format) }
    var media by remember { mutableStateOf(book.media.ifEmpty { listOf(BookMedium.PRINT) }) }
    val trimmed = title.trim()
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Titre et auteur"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                ToolbarIconButton(L("Enregistrer"), "checkmark", prominent = true, enabled = trimmed.isNotEmpty()) {
                    val list = authors.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                    onSave(
                        BookCorrection(
                            title = trimmed.takeIf { it != book.title },
                            authors = list.takeIf { it != book.authors },
                            format = format.takeIf { it != book.format },
                            media = media.takeIf { format != BookFormat.AUDIOBOOK && it != book.media },
                        ),
                    )
                    dismiss()
                }
            },
        )
        FormSection(footer = L("Séparez les auteurs par des virgules."), modifier = Modifier.padding(vertical = 12.dp)) {
            FormRow { PlainTextField(title, { title = it }, L("Titre"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words) }
            FormRow { PlainTextField(authors, { authors = it }, L("Auteur"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words) }
            MenuPicker(format, BookFormat.entries, { it.label }, { format = it }, divider = format != BookFormat.AUDIOBOOK, symbol = { it.symbol }) { RowLabel(L("Format"), "books.vertical") }
            if (format != BookFormat.AUDIOBOOK) MediaToggles(media) { media = it }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ScanReviewPagePreview() = PreviewSurface {
    ScanReviewPage(
        DebugFixtures.reviewDraft,
        ownedCopy = null,
        isSaving = false,
        awaitable = emptyList(),
        loadSubgenres = { emptyList() },
        loadVocabulary = { null },
    ) {}
}
