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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.rememberContactPicker
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** "Conseillé par un ami": who, picked from the contacts or typed, and what they said. */
@Composable
fun RecommendationSheet(current: BookRecommendation?, onDismiss: () -> Unit, onSave: suspend (BookRecommendation?) -> String?) {
    var name by remember { mutableStateOf(current?.recommenderName ?: "") }
    var comment by remember { mutableStateOf(current?.comment ?: "") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val pickContact = rememberContactPicker { name = it }
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    val edited = run {
        val n = name.trim()
        val c = comment.trim()
        if (n.isEmpty() && c.isEmpty()) null else BookRecommendation(n.ifEmpty { null }, c.ifEmpty { null })
    }
    ShioriSheet(onDismiss) { dismiss ->
        suspend fun save(recommendation: BookRecommendation?) {
            saving = true
            val failure = onSave(recommendation)
            saving = false
            if (failure != null) error = failure else dismiss()
        }
        SheetBar(
            L("Conseillé par un ami"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = { AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = edited != current && !saving) { save(edited) } },
        )
        Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            FormSection {
                FormRow {
                    Icon(Symbol("person.badge.plus"), null, Modifier.size(20.dp), tint = colors.secondaryLabel)
                    Text(L("Conseillé par"), style = Shiori.type.body, color = colors.secondaryLabel)
                    PlainTextField(name, { name = it }, L("Nom"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End)
                    Icon(Symbol("person.crop.circle"), L("Choisir dans les contacts"), Modifier.size(28.dp).plainClickable(onClick = pickContact), tint = colors.accent)
                }
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Symbol("text.quote"), null, Modifier.size(16.dp), tint = colors.secondaryLabel)
                        Text(L("Pourquoi ce conseil ?"), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    }
                    PlainTextField(comment, { comment = it }, L("Ce qu'on vous en a dit…"), singleLine = false, minLines = 3, maxLines = 6)
                }
            }
            if (current != null) {
                FormSection {
                    FormRow(divider = false, onClick = { scope.launch { save(null) } }) {
                        Text(L("Retirer le conseil"), style = Shiori.type.body, color = colors.red)
                    }
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}

@Preview(showBackground = true)
@Composable
private fun RecommendationSheetPreview() = PreviewSurface {
    RecommendationSheet(com.polyforms.shiori.shared.BookRecommendation("Léa", "Lis-le !"), onDismiss = {}) { null }
}
