package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.BookFact
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.RoundedTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** One field edited on its own: a number typed, or a day picked on a calendar. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FieldEditSheet(book: Book, field: BookField, onDismiss: () -> Unit, onSave: suspend (BookCorrection) -> String?) {
    var text by remember {
        mutableStateOf(
            when (field) {
                BookField.FIRST_PUBLISHED_IN -> book.firstPublishedIn?.toString() ?: ""
                BookField.PAGE_COUNT -> book.pageCount?.toString() ?: ""
                BookField.ISBN13 -> book.isbn13 ?: ""
                else -> ""
            },
        )
    }
    val original: Instant? = when (field) {
        BookField.ADDED_AT -> book.addedAt
        BookField.STARTED_AT -> book.startedAt
        BookField.FINISHED_AT -> book.finishedAt
        else -> null
    }
    var error by remember { mutableStateOf<String?>(null) }
    val focus = remember { FocusRequester() }
    val colors = Shiori.colors
    val trimmed = text.trim()
    val digits = text.filter { !it.isWhitespace() && it != '-' }
    val problem = when {
        field == BookField.FIRST_PUBLISHED_IN && trimmed.isNotEmpty() && trimmed.toIntOrNull() == null -> L("L'année doit être un nombre.")
        field == BookField.PAGE_COUNT && trimmed.isNotEmpty() && (trimmed.toIntOrNull() ?: 0) < 1 -> L("Le nombre de pages doit être un nombre positif.")
        field == BookField.ISBN13 && digits.isNotEmpty() && !BookFact.isValidIsbn13(digits) -> L("L'ISBN doit compter 13 chiffres valides.")
        else -> null
    }
    val latest = listOfNotNull(Instant.now(), book.addedAt, book.startedAt, book.finishedAt).max()
    val picker = rememberDatePickerState(
        initialSelectedDateMillis = (original ?: Instant.now()).atZone(ZoneId.systemDefault()).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= latest.toEpochMilli() + 86_400_000
        },
    )
    fun pickedInstant(): Instant? {
        val millis = picker.selectedDateMillis ?: return null
        val day = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
        val time = (original ?: Instant.now()).atZone(ZoneId.systemDefault()).toLocalTime()
        return minOf(day.atTime(time).atZone(ZoneId.systemDefault()).toInstant(), latest)
    }
    fun correction(): BookCorrection = when (field) {
        BookField.ADDED_AT -> pickedInstant().takeIf { it != original }?.let { BookCorrection(addedAt = it) } ?: BookCorrection()
        BookField.STARTED_AT -> pickedInstant().takeIf { it != original }?.let { BookCorrection(startedAt = it) } ?: BookCorrection()
        BookField.FINISHED_AT -> pickedInstant().takeIf { it != original }?.let { BookCorrection(finishedAt = it) } ?: BookCorrection()
        else -> field.fact?.correction(text, book) ?: BookCorrection()
    }
    LaunchedEffect(Unit) { if (!field.isDate) focus.requestFocus() }
    ShioriSheet(onDismiss) { dismiss ->
        suspend fun save() {
            val failure = onSave(correction())
            if (failure != null) error = failure else dismiss()
        }
        if (field.isDate) {
            var lastPicked by remember { mutableStateOf(picker.selectedDateMillis) }
            LaunchedEffect(picker.selectedDateMillis) {
                if (picker.selectedDateMillis != lastPicked) {
                    lastPicked = picker.selectedDateMillis
                    save()
                }
            }
        }
        SheetBar(
            field.title,
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = { AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = !correction().isEmpty && problem == null) { save() } },
        )
        Column(Modifier.fillMaxWidth().padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (field.isDate) {
                DatePicker(
                    picker,
                    title = null,
                    headline = null,
                    showModeToggle = false,
                    colors = DatePickerDefaults.colors(
                        containerColor = colors.groupedBackground,
                        selectedDayContainerColor = colors.accent,
                        todayDateBorderColor = colors.accent,
                        todayContentColor = colors.accent,
                    ),
                )
            } else {
                RoundedTextField(text, { text = it }, field.title, keyboardType = KeyboardType.Number, focusRequester = focus)
                Text(
                    problem ?: L("Un champ vidé est effacé."),
                    style = Shiori.type.footnote,
                    color = if (problem != null) colors.red else colors.secondaryLabel,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
    error?.let { ShioriAlert(L("Impossible d'enregistrer"), it, onDismiss = { error = null }) }
}

@Preview(showBackground = true)
@Composable
private fun FieldEditSheetPreview() = PreviewSurface {
    FieldEditSheet(DebugFixtures.reading[0], BookField.PAGE_COUNT, onDismiss = {}) { null }
}
