package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.CoverChoice
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.RoundedTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import java.net.URI

fun CoverChoice.Source.label(): String = when (this) {
    CoverChoice.Source.KINDLE -> L("Kindle")
    CoverChoice.Source.PHOTO -> L("Votre photo")
    CoverChoice.Source.AMAZON -> L("Amazon")
    CoverChoice.Source.OPEN_LIBRARY -> L("Open Library")
    CoverChoice.Source.OTHER_EDITION -> L("Autre édition")
    CoverChoice.Source.WEB -> L("Web")
}

/** The covers found for a book, three a row, and an image address pasted. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CoverPickerSheet(
    book: Book,
    choices: List<CoverChoice>?,
    loadFailed: String?,
    onDismiss: () -> Unit,
    onChoose: suspend (CoverChoice) -> String?,
) {
    var picked by remember { mutableStateOf<String?>(null) }
    var pasted by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    val colors = Shiori.colors
    val typed = pasted.trim()
    val pastedChoice = if (typed.startsWith("https://") && runCatching { URI(typed).host }.getOrNull() != null) {
        choices?.firstOrNull { it.url == typed } ?: CoverChoice(CoverChoice.Source.WEB, typed, false)
    } else {
        null
    }
    if (pastedChoice != null && picked != pastedChoice.url) picked = pastedChoice.url
    val found = choices.orEmpty()
    val offered = if (pastedChoice != null && pastedChoice !in found) found + pastedChoice else found
    val selection = picked ?: choices?.firstOrNull { it.isCurrent }?.url
    val chosen = offered.firstOrNull { it.url == selection }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(
            L("Couverture"),
            leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } },
            trailing = {
                AsyncToolbarButton(L("Choisir cette couverture"), "checkmark", prominent = true, enabled = chosen != null && !chosen.isCurrent) {
                    val failure = chosen?.let { onChoose(it) }
                    if (failure != null) error = failure else dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            when {
                choices != null && offered.isEmpty() -> Text(
                    L("Aucune couverture trouvée pour ce livre. Collez l'adresse d'une image."),
                    style = Shiori.type.body,
                    color = colors.secondaryLabel,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                )
                choices != null -> FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(22.dp), maxItemsInEachRow = 3) {
                    offered.forEach { choice ->
                        val isPicked = choice.url == selection
                        Column(Modifier.width(104.dp).plainClickable { picked = choice.url }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box {
                                Box(
                                    Modifier
                                        .border(3.dp, if (isPicked) colors.accent else Color.Transparent, RoundedCornerShape(10.dp))
                                        .padding(4.dp),
                                ) {
                                    BookCover(book.copy(coverURL = choice.url), 96.dp, showsFormatBadge = false)
                                    if (choice.isCurrent) {
                                        Text(
                                            L("Actuelle"),
                                            style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                                            color = Color.White,
                                            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 8.dp)
                                                .background(Color.Black.copy(alpha = 0.7f), CircleShape).padding(horizontal = 9.dp, vertical = 4.dp),
                                        )
                                    }
                                }
                                if (isPicked) {
                                    Box(
                                        Modifier.align(Alignment.TopEnd).offset(8.dp, (-8).dp).size(26.dp)
                                            .background(colors.accent, CircleShape).border(2.5.dp, colors.groupedBackground, CircleShape),
                                        contentAlignment = Alignment.Center,
                                    ) { Icon(Symbol("checkmark"), null, Modifier.size(13.dp), tint = Color.White) }
                                }
                            }
                            Text(choice.source.label(), style = Shiori.type.caption, color = if (isPicked) colors.label else colors.secondaryLabel, maxLines = 1)
                        }
                    }
                }
                loadFailed != null -> Text(loadFailed, style = Shiori.type.body, color = colors.secondaryLabel, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp))
                else -> Column(Modifier.fillMaxWidth().padding(vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    CircularProgressIndicator()
                    Text(L("Recherche des couvertures…"), style = Shiori.type.callout, color = colors.secondaryLabel)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                RoundedTextField(pasted, { pasted = it }, L("Coller l'adresse d'une image"), keyboardType = KeyboardType.Uri, leadingSymbol = "link")
                if (typed.isNotEmpty() && pastedChoice == null) {
                    Text(L("L'URL doit commencer par https://."), style = Shiori.type.footnote, color = colors.red, modifier = Modifier.padding(horizontal = 14.dp))
                }
            }
        }
    }
    error?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { error = null }) }
}
