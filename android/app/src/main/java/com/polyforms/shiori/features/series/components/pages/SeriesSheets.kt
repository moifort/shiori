package com.polyforms.shiori.features.series.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.series.SeriesCorrection
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.LanguageTag
import com.polyforms.shiori.shared.components.atoms.SagaName
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.MenuPicker
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.RoundedTextField
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A saga's name, format and description, as the shared catalogue holds them. */
@Composable
fun SeriesEditSheet(
    name: String,
    format: BookFormat,
    description: String?,
    isAudio: Boolean,
    isCatalogued: Boolean,
    onDismiss: () -> Unit,
    onSave: suspend (SeriesCorrection) -> String?,
) {
    var editedName by remember { mutableStateOf(name) }
    var editedFormat by remember { mutableStateOf(format) }
    var editedDescription by remember { mutableStateOf(description ?: "") }
    var error by remember { mutableStateOf<String?>(null) }
    val trimmedName = editedName.trim()
    val text = editedDescription.trim()
    val correction = SeriesCorrection(
        name = trimmedName.takeIf { it.isNotEmpty() && it != name },
        format = editedFormat.takeIf { !isAudio && it != format },
        description = if (isCatalogued && text != (description ?: "")) (if (text.isEmpty()) Change.Clear else Change.Set(text)) else null,
    )
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Modifier"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = trimmedName.isNotEmpty() && !correction.isEmpty) {
                    val failure = onSave(correction)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            FormSection(footer = if (trimmedName.isEmpty()) L("Une série a besoin d'un nom.") else null) {
                FormRow(divider = !isAudio) {
                    RowLabel(L("Nom"), "textformat")
                    PlainTextField(editedName, { editedName = it }, L("Nom"), Modifier.weight(1f), capitalization = KeyboardCapitalization.Words, textAlign = TextAlign.End, singleLine = false, maxLines = 3)
                }
                if (!isAudio) {
                    MenuPicker(editedFormat, BookFormat.entries.filter { it != BookFormat.AUDIOBOOK }, { it.label }, { editedFormat = it }, divider = false, symbol = { it.symbol }) {
                        RowLabel(L("Format"), "books.vertical")
                    }
                }
            }
            if (isCatalogued) {
                FormSection(L("Résumé")) {
                    PlainTextField(editedDescription, { editedDescription = it }, L("Résumé"), Modifier.padding(16.dp), singleLine = false, minLines = 3, maxLines = 12)
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Impossible d'enregistrer"), it, onDismiss = { error = null }) }
}

/** The reader's count of a saga nobody catalogued. */
@Composable
fun VolumeCountSheet(seriesName: String, count: Int, onDismiss: () -> Unit, onSave: suspend (Int) -> String?) {
    var value by remember { mutableIntStateOf(count) }
    var text by remember { mutableStateOf(count.toString()) }
    var error by remember { mutableStateOf<String?>(null) }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            seriesName,
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Enregistrer"), "checkmark", prominent = true, enabled = value in 1..200) {
                    val failure = onSave(value)
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        FormSection(
            footer = L("Vos tomes prendront leur place dans la série, et ceux qui vous manquent seront listés par leur numéro. Le catalogue complet remplacera ce décompte dès que Shiori pourra le constituer."),
            modifier = Modifier.padding(vertical = 12.dp).navigationBarsPadding(),
        ) {
            FormRow(divider = false) {
                Text(L("Nombre de tomes"), style = Shiori.type.body, color = Shiori.colors.label, modifier = Modifier.weight(1f))
                ShioriButton("−", kind = ButtonKind.BORDERED) { if (value > 1) { value--; text = value.toString() } }
                PlainTextField(text, { typed -> text = typed.filter { it.isDigit() }.take(3); text.toIntOrNull()?.let { value = it } }, "", Modifier.padding(horizontal = 8.dp).weight(0.3f), keyboardType = KeyboardType.Number, textAlign = TextAlign.Center)
                ShioriButton("+", kind = ButtonKind.BORDERED) { if (value < 200) { value++; text = value.toString() } }
            }
        }
    }
    error?.let { ShioriAlert(L("Enregistrement impossible"), it, onDismiss = { error = null }) }
}

/** Another of the reader's sagas to fold this one into, the same author's first. */
@Composable
fun MergeSeriesSheet(
    seriesId: String,
    seriesName: String,
    isAudio: Boolean,
    author: String?,
    ownedCount: Int,
    loadCandidates: suspend () -> List<FollowedSeries>,
    onDismiss: () -> Unit,
    onMerge: suspend (FollowedSeries) -> String?,
) {
    var candidates by remember { mutableStateOf(emptyList<FollowedSeries>()) }
    var loading by remember { mutableStateOf(true) }
    var query by remember { mutableStateOf("") }
    var picked by remember { mutableStateOf<FollowedSeries?>(null) }
    var merging by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    LaunchedEffect(Unit) {
        try {
            candidates = loadCandidates().filter { it.seriesId != seriesId && it.isAudio == isAudio }
        } catch (failure: Exception) {
            error = reportError(failure)
        } finally {
            loading = false
        }
    }
    val needle = query.trim()
    val kept = if (needle.isEmpty()) candidates else candidates.filter { it.name.contains(needle, true) || it.author?.contains(needle, true) == true }
    val shown = if (author == null) kept else kept.filter { it.author == author } + kept.filter { it.author != author }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(L("Fusionner avec…"), leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } })
        RoundedTextField(query, { query = it }, L("Rechercher une série"), Modifier.padding(horizontal = 16.dp), leadingSymbol = "magnifyingglass")
        Box(Modifier.fillMaxWidth().heightIn(min = 300.dp).padding(top = 12.dp).navigationBarsPadding()) {
            when {
                loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                shown.isEmpty() -> EmptyState(
                    "square.stack.3d.up.slash",
                    if (query.isEmpty()) L("Aucune autre série") else L("Aucun résultat"),
                    if (query.isEmpty()) L("Votre bibliothèque ne compte aucune autre série dans laquelle fusionner celle-ci.") else "",
                )
                else -> Column(Modifier.verticalScroll(rememberScrollState())) {
                    FormSection(footer = L("Les livres de « %@ » rejoindront la série choisie, à leur numéro de tome.", seriesName)) {
                        shown.forEachIndexed { index, candidate ->
                            FormRow(divider = index < shown.lastIndex, onClick = { picked = candidate }) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    SagaName(candidate.name, candidate.isAudio, Shiori.type.body.copy(fontWeight = FontWeight.Medium))
                                    candidate.author?.let { Text(it, style = Shiori.type.subheadline, color = colors.secondaryLabel) }
                                }
                                candidate.language?.takeIf { it.isForeign }?.let { LanguageTag(it) }
                                Text("${candidate.ownedCount}", style = Shiori.type.subheadline, color = colors.secondaryLabel)
                            }
                        }
                    }
                    Spacer(Modifier.heightIn(min = 24.dp))
                }
            }
            if (merging) CircularProgressIndicator(Modifier.align(Alignment.Center))
        }
        picked?.let { target ->
            ShioriAlert(
                L("Fusionner dans « %@ » ?", target.name),
                L("Les %lld livres de « %@ » passeront dans « %@ », et « %@ » sera supprimée avec votre note.", ownedCount, seriesName, target.name, seriesName),
                onDismiss = { picked = null },
                confirm = L("Fusionner"),
                dismissLabel = L("Annuler"),
                destructive = true,
                onConfirm = {
                    picked = null
                    merging = true
                    scope.launch {
                        val message = onMerge(target)
                        merging = false
                        if (message != null) error = message else dismiss()
                    }
                },
            )
        }
    }
    error?.let { ShioriAlert(L("Fusion impossible"), it, onDismiss = { error = null }) }
}

@Preview(showBackground = true)
@Composable
private fun SeriesSheetsPreview() = PreviewSurface {
    VolumeCountSheet("Frieren", count = 15, onDismiss = {}) { null }
}
