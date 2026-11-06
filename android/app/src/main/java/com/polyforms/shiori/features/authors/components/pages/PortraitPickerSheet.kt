package com.polyforms.shiori.features.authors.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.PortraitChoice
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import java.net.URI

private val portraitSize = 92.dp

/** The faces found for a person, three to a row, and a field to paste one from the web. */
@Composable
fun PortraitPickerSheet(
    initials: String,
    choices: List<PortraitChoice>?,
    loadFailed: String?,
    onLoad: suspend () -> Unit,
    onDismiss: () -> Unit,
    onChoose: suspend (PortraitChoice) -> String?,
) {
    var picked by remember { mutableStateOf<String?>(null) }
    var pasted by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { onLoad() }

    val pastedChoice = pastedChoice(pasted, choices)
    val offered = (choices ?: emptyList()).let { found -> if (pastedChoice != null && pastedChoice !in found) found + pastedChoice else found }
    val selection = picked ?: choices?.firstOrNull { it.isCurrent }?.url
    val chosen = offered.firstOrNull { it.url == selection }
    LaunchedEffect(pastedChoice?.url) { pastedChoice?.url?.let { picked = it } }

    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Portrait"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Choisir ce portrait"), "checkmark", prominent = true, enabled = chosen != null && !chosen.isCurrent) {
                    val failure = chosen?.let { onChoose(it) }
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            val colors = Shiori.colors
            when {
                choices != null && offered.isEmpty() -> Message(L("Aucun portrait trouvé pour cet auteur. Collez l'adresse d'une image."))
                choices != null -> offered.chunked(3).forEach { row ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        row.forEach { choice ->
                            Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                                Tile(initials, choice, choice.url == selection) { picked = choice.url }
                            }
                        }
                        repeat(3 - row.size) { Box(Modifier.weight(1f)) }
                    }
                }
                loadFailed != null -> Message(loadFailed)
                else -> Column(Modifier.fillMaxWidth().padding(vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    CircularProgressIndicator()
                    Text(L("Recherche des portraits…"), style = Shiori.type.callout, color = colors.secondaryLabel)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    Modifier.fillMaxWidth().background(colors.secondaryGroupedBackground, RoundedCornerShape(12.dp)).padding(14.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Symbol("link"), null, Modifier.padding(top = 2.dp).size(20.dp), tint = colors.accent)
                    PlainTextField(
                        pasted,
                        { pasted = it },
                        L("Coller l'adresse d'une image"),
                        Modifier.weight(1f),
                        keyboardType = KeyboardType.Uri,
                        capitalization = KeyboardCapitalization.None,
                        singleLine = false,
                    )
                }
                if (pasted.isNotBlank() && pastedChoice == null) {
                    Text(L("L'URL doit commencer par https://."), style = Shiori.type.footnote, color = colors.red, modifier = Modifier.padding(horizontal = 14.dp))
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}

@Composable
private fun Message(text: String) {
    Text(
        text,
        style = Shiori.type.body,
        color = Shiori.colors.secondaryLabel,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
    )
}

@Composable
private fun Tile(initials: String, choice: PortraitChoice, isPicked: Boolean, onPick: () -> Unit) {
    val colors = Shiori.colors
    Column(Modifier.plainClickable(onClick = onPick), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box {
            Box(Modifier.border(3.dp, if (isPicked) colors.accent else Color.Transparent, CircleShape).padding(4.dp)) {
                AuthorAvatar(initials, choice.url, size = portraitSize)
                if (choice.isCurrent) {
                    Text(
                        L("Actuel"),
                        style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 4.dp)
                            .background(Color.Black.copy(alpha = 0.7f), CircleShape).padding(horizontal = 9.dp, vertical = 4.dp),
                    )
                }
            }
            if (isPicked) {
                Box(
                    Modifier.align(Alignment.TopEnd).size(26.dp).background(colors.groupedBackground, CircleShape).padding(2.5.dp).background(colors.accent, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol("checkmark"), null, Modifier.size(13.dp), tint = Color.White)
                }
            }
        }
        Text(
            label(choice.source),
            style = Shiori.type.caption,
            color = if (isPicked) colors.label else colors.secondaryLabel,
            maxLines = 1,
        )
    }
}

private fun label(source: PortraitChoice.Source): String = when (source) {
    PortraitChoice.Source.WIKIPEDIA -> L("Wikipédia")
    PortraitChoice.Source.WIKIDATA -> L("Wikidata")
    PortraitChoice.Source.OPEN_LIBRARY -> L("Open Library")
    PortraitChoice.Source.WEB -> L("Web")
}

private fun pastedChoice(pasted: String, choices: List<PortraitChoice>?): PortraitChoice? {
    val typed = pasted.trim()
    if (!typed.startsWith("https://")) return null
    val host = runCatching { URI(typed).host }.getOrNull() ?: return null
    if (host.isEmpty()) return null
    return choices?.firstOrNull { it.url == typed } ?: PortraitChoice(PortraitChoice.Source.WEB, typed, false)
}
