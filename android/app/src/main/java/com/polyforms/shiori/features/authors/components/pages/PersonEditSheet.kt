package com.polyforms.shiori.features.authors.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.PersonCorrection
import com.polyforms.shiori.features.authors.PersonFacts
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import java.time.LocalDate
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Corrects what the catalogue says of a person: nationality, years, biography. */
@Composable
fun PersonEditSheet(facts: PersonFacts, onDismiss: () -> Unit, onSave: suspend (PersonCorrection) -> String?) {
    var nationality by remember { mutableStateOf(facts.nationality ?: "") }
    var birthYear by remember { mutableStateOf(facts.birthYear?.toString() ?: "") }
    var deathYear by remember { mutableStateOf(facts.deathYear?.toString() ?: "") }
    var biography by remember { mutableStateOf(facts.biography ?: "") }
    var error by remember { mutableStateOf<String?>(null) }

    val problem = yearProblem(birthYear.trim(), deathYear.trim())
    val correction = PersonCorrection(
        nationality = change(facts.nationality, nationality.trim().ifEmpty { null }),
        birthYear = change(facts.birthYear, birthYear.trim().toIntOrNull()),
        deathYear = change(facts.deathYear, deathYear.trim().toIntOrNull()),
        biography = change(facts.biography, biography.trim().ifEmpty { null }),
    )
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Modifier"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = problem == null && !correction.isEmpty) {
                    val failure = onSave(correction)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            FormSection(footer = problem) {
                FormRow {
                    RowLabel(L("Nationalité"), "globe")
                    PlainTextField(nationality, { nationality = it }, L("Nationalité"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End)
                }
                FormRow {
                    RowLabel(L("Naissance"), "calendar")
                    PlainTextField(birthYear, { birthYear = it }, L("Année"), Modifier.weight(1f), keyboardType = KeyboardType.Number, textAlign = TextAlign.End)
                }
                FormRow(divider = false) {
                    RowLabel(L("Décès"), "calendar.badge.minus")
                    PlainTextField(deathYear, { deathYear = it }, L("Année"), Modifier.weight(1f), keyboardType = KeyboardType.Number, textAlign = TextAlign.End)
                }
            }
            FormSection(L("Biographie")) {
                PlainTextField(biography, { biography = it }, L("Biographie"), Modifier.padding(16.dp), singleLine = false, minLines = 3, maxLines = 12)
            }
        }
    }
    error?.let { ShioriAlert(L("Impossible d'enregistrer"), it, onDismiss = { error = null }) }
}

private fun yearProblem(birth: String, death: String): String? {
    val latest = LocalDate.now().year + 10
    for (text in listOf(birth, death)) {
        if (text.isEmpty()) continue
        val year = text.toIntOrNull()
        if (year == null || year !in 1450..latest) return L("L'année doit être un nombre à partir de 1450.")
    }
    val born = birth.toIntOrNull()
    val died = death.toIntOrNull()
    if (born != null && died != null && died < born) return L("L'année de décès précède celle de naissance.")
    return null
}

private fun <T> change(old: T?, new: T?): Change<T>? = when {
    old == new -> null
    new == null -> Change.Clear
    else -> Change.Set(new)
}

@Preview(showBackground = true)
@Composable
private fun PersonEditSheetPreview() = PreviewSurface {
    PersonEditSheet(DebugFixtures.authorPage.facts, onDismiss = {}) { null }
}
