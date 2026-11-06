package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.book.SeriesPlacement
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.BookFact
import com.polyforms.shiori.shared.book.MediaToggles
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.InteractiveStarRating
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.molecules.SeriesNameField
import com.polyforms.shiori.shared.components.molecules.SubgenreField
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

object BookEditRules {
    /** "14h30", "14 h", "45 min", or bare minutes. */
    fun minutes(text: String): Int? {
        val compact = text.lowercase().filter { !it.isWhitespace() }
        if (compact.isEmpty()) return null
        compact.toIntOrNull()?.let { return if (it > 0) it else null }
        val match = Regex("^(?:(\\d+)h)?(?:(\\d+)(?:min|mn|m)?)?$").matchEntire(compact) ?: return null
        val hours = match.groupValues[1].toIntOrNull() ?: 0
        val minutes = match.groupValues[2].toIntOrNull() ?: 0
        if (match.groupValues[1].isEmpty() && !(compact.endsWith("min") || compact.endsWith("mn") || compact.endsWith("m"))) return null
        val total = hours * 60 + minutes
        return if (total > 0) total else null
    }

    fun durationText(minutes: Int): String {
        val hours = minutes / 60
        val rest = minutes % 60
        if (hours == 0) return "${rest}min"
        return if (rest == 0) "${hours}h" else "%dh%02d".format(hours, rest)
    }
}

/** Every fact of a book, the reader's rating and dates, and its saga, in one form. */
@Composable
fun BookEditSheet(
    book: Book,
    loadVocabulary: suspend () -> BookVocabulary?,
    onDismiss: () -> Unit,
    onSave: suspend (BookCorrection, Double?) -> String?,
) {
    var title by remember { mutableStateOf(book.title) }
    var authors by remember { mutableStateOf(book.authors.joinToString(", ")) }
    var format by remember { mutableStateOf(book.format) }
    var media by remember { mutableStateOf(book.media.ifEmpty { listOf(BookMedium.PRINT) }) }
    var rating by remember { mutableDoubleStateOf(book.rating ?: 0.0) }
    var synopsis by remember { mutableStateOf(book.synopsis ?: "") }
    var publisher by remember { mutableStateOf(book.publisher ?: "") }
    var year by remember { mutableStateOf(book.firstPublishedIn?.toString() ?: "") }
    var pages by remember { mutableStateOf(book.pageCount?.toString() ?: "") }
    var duration by remember { mutableStateOf(book.durationMinutes?.let(BookEditRules::durationText) ?: "") }
    var narrators by remember { mutableStateOf(book.narrators.joinToString(", ")) }
    var genre by remember { mutableStateOf(book.genre) }
    var language by remember { mutableStateOf(book.language) }
    var subgenres by remember { mutableStateOf(book.subgenres.joinToString(", ")) }
    var isbn by remember { mutableStateOf(book.isbn13 ?: "") }
    var seriesName by remember { mutableStateOf(book.series?.name ?: "") }
    var seriesVolume by remember { mutableStateOf(book.series?.volume?.toString() ?: "") }
    var isAnnex by remember { mutableStateOf(book.series?.isAnnex ?: false) }
    var annexNumber by remember { mutableStateOf(book.series?.annexNumber?.toString() ?: "") }
    var addedAt by remember { mutableStateOf(book.addedAt ?: Instant.now()) }
    var startedAt by remember { mutableStateOf(book.startedAt ?: Instant.now()) }
    var finishedAt by remember { mutableStateOf(book.finishedAt ?: Instant.now()) }
    var subgenreSuggestions by remember { mutableStateOf(emptyList<String>()) }
    var seriesSuggestions by remember { mutableStateOf(emptyList<String>()) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        loadVocabulary()?.let {
            subgenreSuggestions = it.subgenres
            seriesSuggestions = it.sagas
        }
    }
    fun list(text: String) = text.split(",").map { it.trim() }.filter { it.isNotEmpty() }
    fun optional(text: String) = text.trim().ifEmpty { null }
    fun <T> change(old: T?, new: T?): Change<T>? = when {
        old == new -> null
        new == null -> Change.Clear
        else -> Change.Set(new)
    }
    val isbnDigits = isbn.filter { !it.isWhitespace() && it != '-' }
    val publicationProblem = when {
        year.trim().isNotEmpty() && year.trim().toIntOrNull() == null -> L("L'année doit être un nombre.")
        format == BookFormat.AUDIOBOOK && duration.trim().isNotEmpty() && BookEditRules.minutes(duration) == null -> L("La durée s'écrit comme 14h30, 14 h ou 45 min.")
        format != BookFormat.AUDIOBOOK && pages.trim().isNotEmpty() && (pages.trim().toIntOrNull() ?: 0) < 1 -> L("Le nombre de pages doit être un nombre positif.")
        isbnDigits.isNotEmpty() && !BookFact.isValidIsbn13(isbnDigits) -> L("L'ISBN doit compter 13 chiffres valides.")
        else -> null
    }
    val seriesProblem = run {
        val name = seriesName.trim()
        if (name.isEmpty()) return@run null
        if (!isAnnex && seriesVolume.trim().isNotEmpty() && (seriesVolume.trim().toIntOrNull() ?: 0) !in 1..200) return@run L("Le tome doit être un nombre entre 1 et 200.")
        if (isAnnex && annexNumber.trim().isNotEmpty() && (annexNumber.trim().toIntOrNull() ?: 0) !in 1..200) return@run L("Le numéro de hors-série doit être un nombre entre 1 et 200.")
        val held = seriesSuggestions.any { it.equals(name, ignoreCase = true) }
        if (list(authors).isEmpty() && !held && name != book.series?.name) L("Ajoutez un auteur pour créer une nouvelle série.") else null
    }
    val isValid = title.trim().isNotEmpty() && publicationProblem == null && seriesProblem == null
    fun correction(): BookCorrection {
        val audio = format == BookFormat.AUDIOBOOK
        return BookCorrection(
            title = title.trim().takeIf { it != book.title && it.isNotEmpty() },
            authors = list(authors).takeIf { it != book.authors },
            format = format.takeIf { it != book.format },
            media = if (!audio && media != book.media) media else null,
            publisher = change(book.publisher, optional(publisher)),
            firstPublishedIn = change(book.firstPublishedIn, year.trim().toIntOrNull()),
            synopsis = change(book.synopsis, optional(synopsis)),
            genre = change(book.genre, genre),
            subgenres = list(subgenres).take(3).takeIf { it != book.subgenres },
            durationMinutes = if (audio) change(book.durationMinutes, BookEditRules.minutes(duration)) else null,
            narrators = if (audio) list(narrators).takeIf { it != book.narrators } else null,
            pageCount = if (!audio) change(book.pageCount, pages.trim().toIntOrNull()) else null,
            isbn13 = change(book.isbn13, isbnDigits.ifEmpty { null }),
            language = change(book.language, language),
            series = change(
                book.series?.let { if (it.isAnnex) SeriesPlacement(it.name, annex = true, annexNumber = it.annexNumber) else SeriesPlacement(it.name, it.volume) },
                optional(seriesName)?.let { name ->
                    if (isAnnex) SeriesPlacement(name, annex = true, annexNumber = annexNumber.trim().toIntOrNull()) else SeriesPlacement(name, seriesVolume.trim().toIntOrNull())
                },
            ),
            addedAt = if (book.addedAt != null && addedAt != book.addedAt) addedAt else null,
            startedAt = if (book.startedAt != null && startedAt != book.startedAt) startedAt else null,
            finishedAt = if (book.finishedAt != null && finishedAt != book.finishedAt) finishedAt else null,
        )
    }
    val colors = Shiori.colors
    val latest = listOfNotNull(Instant.now(), book.addedAt, book.startedAt, book.finishedAt).max()
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Modifier"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = isValid) {
                    val failure = onSave(correction(), if (rating == 0.0) null else rating)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(vertical = 12.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            FormSection(
                footer = if (title.trim().isEmpty()) L("Un livre a besoin d'un titre.") else if (format == BookFormat.AUDIOBOOK) L("Séparez les auteurs et les narrateurs par des virgules.") else L("Séparez les auteurs par des virgules."),
            ) {
                LabeledField(L("Titre"), "textformat") { PlainTextField(title, { title = it }, L("Titre"), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End, singleLine = false, maxLines = 3) }
                LabeledField(L("Auteurs"), "author") { PlainTextField(authors, { authors = it }, L("Auteur"), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End, singleLine = false, maxLines = 3) }
                if (format == BookFormat.AUDIOBOOK) {
                    LabeledField(L("Narrateurs"), "music.mic") { PlainTextField(narrators, { narrators = it }, L("Narrateur"), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End, singleLine = false, maxLines = 3) }
                }
                MenuPicker(format, BookFormat.entries, { it.label }, { format = it }, divider = format != BookFormat.AUDIOBOOK, symbol = { it.symbol }) { RowLabel(L("Format"), "books.vertical") }
                if (format != BookFormat.AUDIOBOOK) MediaToggles(media) { media = it }
            }
            FormSection(L("Ma lecture"), if (rating == 0.0) L("Noter un livre le marque comme lu.") else L("Touchez l'étoile sélectionnée pour retirer la note.")) {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Symbol("star"), null, Modifier.size(18.dp), tint = colors.secondaryLabel)
                        Text(L("Note"), style = Shiori.type.body, color = colors.secondaryLabel)
                    }
                    InteractiveStarRating(rating, { rating = it })
                }
                if (book.addedAt != null) DateRow(L("Ajouté le"), "tray.and.arrow.down", addedAt, latest) {
                    addedAt = it
                    if (book.startedAt != null && startedAt < it) startedAt = it
                    if (book.finishedAt != null && finishedAt < it) finishedAt = it
                }
                if (book.startedAt != null) DateRow(L("Commencé le"), "calendar.badge.plus", startedAt, latest) {
                    startedAt = it
                    if (book.addedAt != null && addedAt > it) addedAt = it
                    if (book.finishedAt != null && finishedAt < it) finishedAt = it
                }
                if (book.finishedAt != null) DateRow(L("Terminé le"), "calendar.badge.checkmark", finishedAt, latest) {
                    finishedAt = it
                    if (book.startedAt != null && startedAt > it) startedAt = it
                    if (book.addedAt != null && addedAt > it) addedAt = it
                }
            }
            FormSection(L("Résumé")) {
                PlainTextField(synopsis, { synopsis = it }, L("Résumé"), Modifier.padding(16.dp), singleLine = false, minLines = 3, maxLines = 12)
            }
            FormSection(
                L("Publication"),
                publicationProblem ?: L("Séparez les sous-genres par des virgules, trois au plus ; le premier est celui qui s'affiche dans la liste. Un champ vidé est effacé."),
            ) {
                LabeledField(L("Éditeur"), "building.2") { PlainTextField(publisher, { publisher = it }, L("Éditeur"), textAlign = TextAlign.End) }
                LabeledField(L("Première parution"), "calendar") { PlainTextField(year, { year = it }, L("Année"), keyboardType = KeyboardType.Number, textAlign = TextAlign.End) }
                if (format == BookFormat.AUDIOBOOK) {
                    LabeledField(L("Durée"), "clock") { PlainTextField(duration, { duration = it }, "14h30", textAlign = TextAlign.End, capitalization = KeyboardCapitalization.None) }
                } else {
                    LabeledField(L("Pages"), "doc.plaintext") { PlainTextField(pages, { pages = it }, L("Pages"), keyboardType = KeyboardType.Number, textAlign = TextAlign.End) }
                }
                MenuPicker(genre, listOf<BookGenre?>(null) + BookGenre.alphabetical, { it?.label ?: L("Non renseigné") }, { genre = it }, symbol = { it?.symbol }) { RowLabel(L("Genre"), "theatermasks") }
                Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Symbol("tag"), null, Modifier.size(18.dp), tint = colors.secondaryLabel)
                        Text(L("Sous-genres"), style = Shiori.type.body, color = colors.secondaryLabel)
                    }
                    SubgenreField(subgenres, { subgenres = it }, subgenreSuggestions)
                }
                MenuPicker(language, listOf<BookLanguage?>(null) + BookLanguage.entries, { it?.label ?: L("Non renseignée") }, { language = it }) { RowLabel(L("Langue"), "globe") }
                LabeledField(L("ISBN"), "barcode", divider = false) { PlainTextField(isbn, { isbn = it }, "978…", keyboardType = KeyboardType.Number, textAlign = TextAlign.End) }
            }
            FormSection(
                L("Série"),
                seriesProblem ?: L("Choisissez une série de votre bibliothèque pour y ranger ce livre avec les autres tomes. Un hors-série — préquelle, nouvelle, guide — se range à part, sous son propre numéro. Videz le nom pour le sortir de sa série."),
            ) {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Symbol("square.stack"), null, Modifier.size(18.dp), tint = colors.secondaryLabel)
                        Text(L("Nom"), style = Shiori.type.body, color = colors.secondaryLabel)
                    }
                    SeriesNameField(seriesName, { seriesName = it }, seriesSuggestions)
                }
                if (seriesName.trim().isNotEmpty()) {
                    FormRow {
                        RowLabel(L("Hors-série"), "square.stack")
                        Spacer(Modifier.weight(1f))
                        ShioriSwitch(isAnnex, { isAnnex = it })
                    }
                    if (isAnnex) {
                        LabeledField(L("Numéro"), "number", divider = false) { PlainTextField(annexNumber, { annexNumber = it }, L("Sans numéro"), keyboardType = KeyboardType.Number, textAlign = TextAlign.End) }
                    } else {
                        LabeledField(L("Tome"), "number", divider = false) { PlainTextField(seriesVolume, { seriesVolume = it }, L("Sans numéro"), keyboardType = KeyboardType.Number, textAlign = TextAlign.End) }
                    }
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Impossible d'enregistrer"), it, onDismiss = { error = null }) }
}

/** `LabeledContent` around a field: the icon and title on the left, the field trailing. */
@Composable
private fun LabeledField(title: String, symbol: String, divider: Boolean = true, field: @Composable () -> Unit) {
    FormRow(divider = divider) {
        RowLabel(title, symbol)
        Column(Modifier.weight(1f)) { field() }
    }
}

/** A day the reader may move, as a compact date picker: the day in a grey capsule. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DateRow(title: String, symbol: String, date: Instant, latest: Instant, onPick: (Instant) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val colors = Shiori.colors
    FormRow {
        RowLabel(title, symbol)
        Spacer(Modifier.weight(1f))
        Text(
            DateText.dayMonthShortYear(DateText.local(date)),
            style = Shiori.type.body,
            color = colors.label,
            modifier = Modifier.plainClickable { open = true }
                .then(Modifier.padding(horizontal = 4.dp)),
        )
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
                    val time = date.atZone(ZoneId.systemDefault()).toLocalTime()
                    onPick(minOf(day.atTime(time).atZone(ZoneId.systemDefault()).toInstant(), latest))
                }) { Text(L("OK"), color = colors.accent) }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text(L("Annuler"), color = colors.accent) } },
        ) { DatePicker(state, showModeToggle = false) }
    }
}
