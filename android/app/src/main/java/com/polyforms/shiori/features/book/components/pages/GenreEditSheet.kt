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
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.molecules.SubgenreField
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet

/** The genre from the closed list, and up to three subgenres. */
@Composable
fun GenreEditSheet(book: Book, loadSubgenres: suspend () -> List<String>, onDismiss: () -> Unit, onSave: suspend (BookCorrection) -> String?) {
    var genre by remember { mutableStateOf(book.genre) }
    var subgenres by remember { mutableStateOf(book.subgenres.joinToString(", ")) }
    var suggestions by remember { mutableStateOf(emptyList<String>()) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suggestions = loadSubgenres() }
    val list = subgenres.split(",").map { it.trim() }.filter { it.isNotEmpty() }.take(3)
    val correction = BookCorrection(
        genre = if (genre != book.genre) genre?.let { Change.Set(it) } ?: Change.Clear else null,
        subgenres = list.takeIf { it != book.subgenres },
    )
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Genre"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = !correction.isEmpty) {
                    val failure = onSave(correction)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        FormSection(
            footer = if (book.series != null) {
                L("Séparez les sous-genres par des virgules, trois au plus. Le genre décrit la série : il sera appliqué à tous ses tomes de votre bibliothèque.")
            } else {
                L("Séparez les sous-genres par des virgules, trois au plus ; le premier est celui qui s'affiche dans la liste.")
            },
            modifier = Modifier.padding(vertical = 12.dp),
        ) {
            MenuPicker(
                genre,
                listOf<BookGenre?>(null) + BookGenre.alphabetical,
                { it?.label ?: L("Non renseigné") },
                { genre = it },
                symbol = { it?.symbol },
            ) { RowLabel(L("Genre"), "theatermasks") }
            Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                Icon(Symbol("tag"), null, Modifier.size(22.dp), tint = Shiori.colors.secondaryLabel)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(L("Sous-genres"), style = Shiori.type.body, color = Shiori.colors.label)
                    SubgenreField(subgenres, { subgenres = it }, suggestions)
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}
