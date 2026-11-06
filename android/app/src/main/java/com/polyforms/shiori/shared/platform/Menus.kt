package com.polyforms.shiori.shared.platform

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/** One entry of a menu, as SwiftUI's `Button(title, systemImage:)` inside a `Menu`. */
sealed interface MenuEntry {
    data class Item(
        val title: String,
        val symbol: String? = null,
        val destructive: Boolean = false,
        val checked: Boolean? = null,
        val action: () -> Unit,
    ) : MenuEntry

    data object Divider : MenuEntry
}

/** The entries of a menu, drawn in a dropdown. */
@Composable
fun MenuEntries(entries: List<MenuEntry>, expanded: Boolean, onDismiss: () -> Unit) {
    DropdownMenu(expanded, onDismiss, containerColor = Shiori.colors.secondaryGroupedBackground) {
        entries.forEach { entry ->
            when (entry) {
                MenuEntry.Divider -> HorizontalDivider(color = Shiori.colors.separator)
                is MenuEntry.Item -> DropdownMenuItem(
                    text = { Text(entry.title, color = if (entry.destructive) Shiori.colors.red else Shiori.colors.label) },
                    leadingIcon = entry.checked?.let { checked ->
                        { Icon(Symbol("checkmark"), null, Modifier.size(18.dp), tint = if (checked) Shiori.colors.label else androidx.compose.ui.graphics.Color.Transparent) }
                    },
                    trailingIcon = entry.symbol?.let { symbol ->
                        { Icon(Symbol(symbol), null, Modifier.size(20.dp), tint = if (entry.destructive) Shiori.colors.red else Shiori.colors.label) }
                    },
                    onClick = {
                        onDismiss()
                        entry.action()
                    },
                )
            }
        }
    }
}

/** A round glass toolbar button that opens a menu: the `…` of a page. */
@Composable
fun ToolbarMenuButton(title: String, symbol: String, entries: List<MenuEntry>, modifier: Modifier = Modifier) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier) {
        ToolbarIconButton(title, symbol) { expanded = true }
        MenuEntries(entries, expanded) { expanded = false }
    }
}

