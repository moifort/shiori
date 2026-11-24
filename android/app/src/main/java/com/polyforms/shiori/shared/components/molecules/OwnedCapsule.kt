package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.actionLabelStyle
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry

/**
 * "Ajouté": a book the reader holds already, in any format, said in the place of "+ Ajouter" — on
 * a large card of Actualité, and on the page of a friend's book or a prize's winner. A glass
 * capsule with a check. With nothing left to do it takes no tap; given menu entries (the editions
 * still to await from a friend's book), it opens them.
 */
@Composable
fun OwnedCapsule(modifier: Modifier = Modifier, size: AddMenuSize = AddMenuSize.CARD, entries: List<MenuEntry> = emptyList()) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier) {
        ActionButton(
            onClick = { expanded = true },
            fill = ActionFill.GLASS,
            height = size.height,
            inert = entries.isEmpty(),
            contentDescription = L("Déjà dans votre bibliothèque"),
        ) {
            Icon(Symbol("checkmark"), null, Modifier.size(if (size == AddMenuSize.CARD) 13.dp else 20.dp), tint = LocalContentColor.current)
            Text(L("Ajouté"), style = actionLabelStyle(size.height), color = LocalContentColor.current, maxLines = 1)
        }
        if (entries.isNotEmpty()) MenuEntries(entries, expanded) { expanded = false }
    }
}

@Preview(showBackground = true)
@Composable
private fun OwnedCapsulePreview() = PreviewSurface(dark = true) {
    Column(Modifier.background(Color.Black).padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        OwnedCapsule()
        OwnedCapsule(size = AddMenuSize.PAGE)
        OwnedCapsule(size = AddMenuSize.PAGE, entries = listOf(MenuEntry.Item(L("Guetter en audio")) {}))
    }
}
