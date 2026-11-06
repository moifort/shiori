package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.book.SeriesPlacement
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.molecules.SeriesNameField
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet

/** File a standalone book in a saga: one of the reader's, or a new one. */
@Composable
fun SeriesJoinSheet(book: Book, loadVocabulary: suspend () -> BookVocabulary?, onDismiss: () -> Unit, onSave: suspend (BookCorrection) -> String?) {
    var name by remember { mutableStateOf(book.series?.name ?: "") }
    var volume by remember { mutableStateOf(book.series?.volume?.toString() ?: "") }
    var suggestions by remember { mutableStateOf(emptyList<String>()) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suggestions = loadVocabulary()?.sagas.orEmpty() }
    val typedName = name.trim()
    val typedVolume = volume.trim()
    val problem = when {
        typedName.isEmpty() -> null
        typedVolume.isNotEmpty() && (typedVolume.toIntOrNull() ?: 0) !in 1..200 -> L("Le tome doit être un nombre entre 1 et 200.")
        book.authors.isEmpty() && suggestions.none { it.equals(typedName, ignoreCase = true) } -> L("Ajoutez un auteur pour créer une nouvelle série.")
        else -> null
    }
    val colors = Shiori.colors
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Série"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = typedName.isNotEmpty() && problem == null) {
                    val failure = onSave(BookCorrection(series = Change.Set(SeriesPlacement(typedName, typedVolume.toIntOrNull()))))
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        FormSection(
            footer = problem ?: L("Choisissez une série de votre bibliothèque pour y ranger ce livre avec les autres tomes, ou nommez-en une nouvelle."),
            modifier = Modifier.padding(vertical = 12.dp),
        ) {
            Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                Icon(Symbol("square.stack"), null, Modifier.size(22.dp), tint = colors.secondaryLabel)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(L("Nom"), style = Shiori.type.body, color = colors.label)
                    SeriesNameField(name, { name = it }, suggestions)
                }
            }
            if (typedName.isNotEmpty()) {
                FormRow(divider = false) {
                    RowLabel(L("Tome"), "number")
                    PlainTextField(volume, { volume = it }, L("Sans numéro"), Modifier.weight(1f), keyboardType = KeyboardType.Number, textAlign = TextAlign.End)
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}
