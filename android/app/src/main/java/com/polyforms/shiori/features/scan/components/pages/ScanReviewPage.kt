package com.polyforms.shiori.features.scan.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.book.SeriesPlacement
import com.polyforms.shiori.features.book.components.pages.GenreEditSheet
import com.polyforms.shiori.features.book.components.pages.RatingPromptSheet
import com.polyforms.shiori.features.book.components.pages.SeriesJoinSheet
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.book.BookFact
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.MediaToggles
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.ReadingStatusPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
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

sealed interface ScanReviewAction {
    data class Save(val draft: BookDraft, val series: SeriesPlacement?) : ScanReviewAction
    data object Retake : ScanReviewAction
    data class AwaitEdition(val draft: BookDraft, val format: ReleaseFormat) : ScanReviewAction
    data class Wish(val draft: BookDraft) : ScanReviewAction
    data class LanguageOrFormatChanged(val language: BookLanguage?, val format: BookFormat) : ScanReviewAction
    data class OpenOwnedCopy(val book: Book) : ScanReviewAction
}

private enum class ReviewSheet { IDENTITY, SERIES, GENRE, RATE }

private fun BookDraft.asReviewedBook(rating: Double, renamed: SeriesPlacement?): Book = Book(
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
    rating = if (rating > 0) rating else null,
)

private fun <T> Change<T>?.valueOr(old: T?): T? = when (this) {
    null -> old
    is Change.Set -> value
    Change.Clear -> null
}

/** A correction read back into the draft. */
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

/** What the AI read off the cover, to check and correct before the book is added. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanReviewPage(
    initial: BookDraft,
    ownedCopy: Book?,
    isSaving: Boolean,
    awaitable: List<ReleaseFormat>,
    loadSubgenres: suspend () -> List<String>,
    loadVocabulary: suspend () -> BookVocabulary?,
    onAction: suspend (ScanReviewAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(initial) }
    var renamed by remember { mutableStateOf<SeriesPlacement?>(null) }
    var sheet by remember { mutableStateOf<ReviewSheet?>(null) }
    var addMenu by remember { mutableStateOf(false) }
    val book = draft.asReviewedBook(draft.rating, renamed)
    val colors = Shiori.colors
    fun send(action: ScanReviewAction) {
        scope.launch { onAction(action) }
    }
    LaunchedEffect(draft.language, draft.format) { onAction(ScanReviewAction.LanguageOrFormatChanged(draft.language, draft.format)) }

    fun markRead() {
        if (draft.status == ReadingStatus.TO_READ || draft.status == ReadingStatus.READING) draft = draft.copy(status = ReadingStatus.READ)
    }
    fun rate(stars: Double) {
        draft = draft.copy(rating = stars, favorite = draft.favorite && stars >= 3)
        if (stars > 0) markRead()
    }
    fun love(loved: Boolean) {
        draft = draft.copy(favorite = loved, rating = if (loved && draft.rating < 3) 5.0 else draft.rating)
        if (loved) markRead()
    }
    val canSave = draft.title.isNotBlank() && !isSaving
    fun save(status: ReadingStatus) {
        var approved = draft
        if (status != approved.status) {
            approved = approved.copy(status = status)
            if (status == ReadingStatus.TO_READ) approved = approved.copy(rating = 0.0, favorite = false)
        }
        draft = approved
        send(ScanReviewAction.Save(approved, renamed))
    }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            if (ownedCopy != null) {
                val joining = mediaJoining(draft, ownedCopy)
                FormSection(
                    footer = if (joining.isEmpty()) L("Vous pouvez l'ajouter une seconde fois, pour une autre édition par exemple.")
                    else L("Il rejoindra votre fiche, désormais en %@. Un seul livre, quel que soit le support.", BookMedium.label(ownedCopy.media + joining)),
                ) {
                    FormRow(divider = false, onClick = { send(ScanReviewAction.OpenOwnedCopy(ownedCopy)) }) {
                        Icon(Symbol(if (joining.isEmpty()) "exclamationmark.triangle.fill" else "link"), null, Modifier.size(20.dp), tint = if (joining.isEmpty()) colors.orange else colors.accent)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text(L("Déjà dans votre bibliothèque"), style = Shiori.type.headline, color = colors.label)
                            Text("${ownedCopy.title} · ${ownedCopy.status.label}", style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
                        }
                        Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
                    }
                }
            }
            Box(Modifier.padding(horizontal = 16.dp)) {
                ReadingStatusPicker(draft.status) { status ->
                    draft = draft.copy(status = status)
                    if (status == ReadingStatus.TO_READ || status == ReadingStatus.READING) draft = draft.copy(rating = 0.0, favorite = false)
                }
            }
            FormSection(footer = L("Lu automatiquement sur la couverture : touchez une ligne pour la corriger avant d'ajouter le livre.")) {
                FormRow(onClick = { sheet = ReviewSheet.IDENTITY }) {
                    BookCover(book, 64.dp)
                    Column(Modifier.weight(1f).padding(start = 12.dp, top = 4.dp, bottom = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(book.title, style = Shiori.type.headline, color = colors.label)
                        Text(listOfNotNull(book.authorLine, book.series?.label?.let { "· $it" }).joinToString(" "), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    }
                }
                FormRow(onClick = { sheet = ReviewSheet.SERIES }) {
                    RowLabel(L("Série"), "square.stack")
                    Spacer(Modifier.weight(1f))
                    Text(book.series?.name ?: L("Aucune"), style = Shiori.type.body, color = colors.accent, textAlign = TextAlign.End)
                    Icon(Symbol("chevron.right"), null, Modifier.padding(start = 4.dp).size(12.dp), tint = colors.accent)
                }
                FormRow(onClick = { sheet = ReviewSheet.GENRE }) {
                    RowLabel(L("Genre"), "books.vertical")
                    Spacer(Modifier.weight(1f))
                    Text(book.genre?.label ?: L("Non renseigné"), style = Shiori.type.body, color = colors.accent)
                    Icon(Symbol("chevron.right"), null, Modifier.padding(start = 4.dp).size(12.dp), tint = colors.accent)
                }
                FormRow {
                    RowLabel(L("Type"), book.format.symbol)
                    Spacer(Modifier.weight(1f))
                    Text(book.format.label, style = Shiori.type.body, color = colors.secondaryLabel)
                }
                if (book.media.isNotEmpty()) {
                    FormRow {
                        RowLabel(L("Support"), if (book.media.size > 1) "books.vertical" else book.media[0].symbol)
                        Spacer(Modifier.weight(1f))
                        Text(BookMedium.label(book.media), style = Shiori.type.body, color = colors.secondaryLabel)
                    }
                }
                BookFact.entries.filter { it.applies(book) }.forEach { fact ->
                    FactField(fact, book) { correction -> draft = draft.applying(correction) }
                }
                val choices = BookLanguage.reviewChoices.let { list -> draft.language?.takeIf { it !in list }?.let { list + it } ?: list }
                MenuPicker(draft.language, choices, { it?.label ?: L("Non renseignée") }, { draft = draft.copy(language = it) }, divider = false) {
                    RowLabel(L("Langue"), "globe")
                }
            }
            FormSection(L("Ma lecture")) {
                FormRow(onClick = { sheet = ReviewSheet.RATE }) {
                    if (draft.rating > 0) {
                        RowLabel(L("Note"), "star")
                        Spacer(Modifier.weight(1f))
                        RatingStars(draft.rating)
                    } else {
                        Icon(Symbol("star"), null, Modifier.size(18.dp), tint = colors.accent)
                        Text(L("Noter ce livre"), style = Shiori.type.body, color = colors.accent, modifier = Modifier.padding(start = 12.dp))
                    }
                }
                FormRow(divider = draft.status != ReadingStatus.TO_READ) {
                    RowLabel(L("Favori"), if (draft.favorite) "heart.fill" else "heart")
                    Spacer(Modifier.weight(1f))
                    ShioriSwitch(draft.favorite, ::love)
                }
                if (draft.status != ReadingStatus.TO_READ) {
                    val latestStart = if (draft.status == ReadingStatus.READ) minOf(draft.finishedAt ?: Instant.now(), Instant.now()) else Instant.now()
                    ReviewDateRow(L("Commencé le"), "calendar.badge.plus", draft.startedAt?.let { minOf(it, latestStart) } ?: latestStart, latestStart, divider = draft.status == ReadingStatus.READ) { date ->
                        draft = draft.copy(startedAt = date, finishedAt = draft.finishedAt?.let { if (draft.status == ReadingStatus.READ && it < date) date else it })
                    }
                    if (draft.status == ReadingStatus.READ) {
                        ReviewDateRow(L("Terminé le"), "calendar.badge.checkmark", draft.finishedAt ?: Instant.now(), Instant.now(), divider = false) { draft = draft.copy(finishedAt = it) }
                    }
                }
            }
            draft.synopsis?.let { synopsis ->
                FormSection(L("Résumé")) { Box(Modifier.padding(16.dp)) { BookSynopsisBlock(synopsis) } }
            }
        }
        Row(Modifier.statusBarsPadding().fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            ToolbarIconButton(L("Reprendre"), "arrow.counterclockwise") { send(ScanReviewAction.Retake) }
            Text(L("Vérifier"), style = Shiori.type.headline, color = colors.label, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            Box {
                ToolbarIconButton(L("Ajouter"), "plus", prominent = true, enabled = !isSaving) { addMenu = true }
                MenuEntries(
                    buildList {
                        add(MenuEntry.Item(L("À lire"), "bookmark.fill") { if (canSave) save(ReadingStatus.TO_READ) })
                        add(MenuEntry.Item(L("Déjà lu"), "checkmark") { if (canSave) save(ReadingStatus.READ) })
                        add(MenuEntry.Divider)
                        add(MenuEntry.Item(L("Liste d'envies"), "bookmark") { if (canSave) send(ScanReviewAction.Wish(draft)) })
                        if (awaitable.isNotEmpty()) {
                            add(MenuEntry.Divider)
                            awaitable.forEach { format ->
                                add(MenuEntry.Item(format.awaitLabel, if (format == ReleaseFormat.AUDIOBOOK) "headphones" else "character.book.closed") {
                                    send(ScanReviewAction.AwaitEdition(draft, format))
                                })
                            }
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
        ReviewSheet.RATE -> RatingPromptSheet(if (draft.rating > 0) draft.rating else null, dismiss, onRemove = {
            sheet = null
            rate(0.0)
        }) { stars ->
            sheet = null
            rate(stars)
        }
        null -> Unit
    }
}

private fun mediaJoining(draft: BookDraft, copy: Book): List<BookMedium> {
    if (draft.format == BookFormat.AUDIOBOOK || copy.format == BookFormat.AUDIOBOOK) return emptyList()
    val language = draft.language
    val held = copy.language
    if (language != null && held != null && language != held) return emptyList()
    return draft.media.filter { it !in copy.media }
}

@Composable
private fun FactField(fact: BookFact, book: Book, onCorrect: (BookCorrection) -> Unit) {
    var text by remember(fact) { mutableStateOf(fact.value(book) ?: "") }
    FormRow {
        RowLabel(fact.title, fact.icon)
        PlainTextField(
            text,
            { typed ->
                text = typed
                fact.correction(typed, book)?.takeIf { !it.isEmpty }?.let(onCorrect)
            },
            "",
            Modifier.weight(1f),
            keyboardType = if (fact.isNumeric) KeyboardType.Number else KeyboardType.Text,
            capitalization = KeyboardCapitalization.Words,
            textAlign = TextAlign.End,
            onDone = {
                val correction = fact.correction(text, book)
                if (correction == null) text = fact.value(book) ?: "" else if (!correction.isEmpty) onCorrect(correction)
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReviewDateRow(title: String, symbol: String, date: Instant, latest: Instant, divider: Boolean, onPick: (Instant) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val colors = Shiori.colors
    FormRow(divider = divider, onClick = { open = true }) {
        RowLabel(title, symbol)
        Spacer(Modifier.weight(1f))
        Text(DateText.dayMonthShortYear(DateText.local(date)), style = Shiori.type.body, color = colors.label)
    }
    if (open) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = DateText.local(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= latest.toEpochMilli() + 86_400_000
            },
        )
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(onClick = {
                    open = false
                    val millis = state.selectedDateMillis ?: return@TextButton
                    val day = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                    onPick(minOf(day.atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), latest))
                }) { Text(L("OK"), color = colors.accent) }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text(L("Annuler"), color = colors.accent) } },
        ) { DatePicker(state, showModeToggle = false) }
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
