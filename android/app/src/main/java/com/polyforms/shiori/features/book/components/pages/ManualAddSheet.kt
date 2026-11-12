package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.MediaToggles
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.ReadingStatusPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.track
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A book typed by hand: title, author, format, media and status; the rest comes from a scan. */
@Composable
fun ManualAddSheet(onDismiss: () -> Unit, onAdd: suspend (BookDraft) -> String?) {
    var title by remember { mutableStateOf("") }
    var author by remember { mutableStateOf("") }
    var format by remember { mutableStateOf(BookFormat.BOOK) }
    var media by remember { mutableStateOf(listOf(BookMedium.PRINT)) }
    var status by remember { mutableStateOf(ReadingStatus.TO_READ) }
    var error by remember { mutableStateOf<String?>(null) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Ajouter un livre"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Ajouter"), "checkmark", prominent = true, enabled = title.isNotBlank()) {
                    val draft = BookDraft(title = title.trim(), authors = listOfNotNull(author.trim().ifEmpty { null }), format = format, media = media, status = status)
                    val failure = onAdd(draft)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            FormSection {
                FormRow { PlainTextField(title, { title = it }, L("Titre"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words, focusRequester = focus) }
                FormRow { PlainTextField(author, { author = it }, L("Auteur (facultatif)"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words) }
                MenuPicker(format, BookFormat.entries, { it.label }, { format = it }, divider = format != BookFormat.AUDIOBOOK, symbol = { it.symbol }) { RowLabel(L("Format"), "books.vertical") }
                if (format != BookFormat.AUDIOBOOK) MediaToggles(media) { media = it }
            }
            FormSection(L("Lecture")) { Box(Modifier.padding(12.dp)) { ReadingStatusPicker(status) { status = it } } }
            Text(
                L("Le résumé, la série et les autres informations ne sont renseignés que par un scan."),
                style = Shiori.type.footnote,
                color = Shiori.colors.secondaryLabel,
                modifier = Modifier.padding(horizontal = 32.dp),
            )
        }
    }
    error?.let { ShioriAlert(L("Impossible d'ajouter ce livre"), it, onDismiss = { error = null }) }
}

/** The manual add, connected: the book is added as typed. */
@Composable
fun ManualAddScreen(onDismiss: () -> Unit, onAdded: (Book) -> Unit) {
    ManualAddSheet(onDismiss) { draft ->
        try {
            val book = BookApi.add(draft)
            track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.MANUAL))
            onAdded(book)
            null
        } catch (failure: Exception) {
            reportError(failure)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ManualAddSheetPreview() = PreviewSurface {
    ManualAddSheet(onDismiss = {}) { null }
}
