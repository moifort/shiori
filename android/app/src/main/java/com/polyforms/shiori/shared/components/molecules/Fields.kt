package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry

@Composable
private fun Proposals(proposals: List<String>, onPick: (String) -> Unit) {
    if (proposals.isEmpty()) return
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        proposals.forEach { proposal ->
            Text(
                proposal,
                style = Shiori.type.caption,
                color = Shiori.colors.label,
                modifier = Modifier.background(Shiori.colors.quaternaryLabel, CircleShape).plainClickable { onPick(proposal) }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
    }
}

/** Subgenres typed comma-separated, with the reader's own proposed as they type, three at most. */
@Composable
fun SubgenreField(text: String, onChange: (String) -> Unit, suggestions: List<String>) {
    val parts = text.split(",").map { it.trim() }
    val committed = parts.dropLast(1).filter { it.isNotEmpty() }
    val current = parts.lastOrNull() ?: ""
    val proposals = if (committed.size >= 3) {
        emptyList()
    } else {
        val taken = committed.map { it.lowercase() }.toSet()
        val prefix = current.lowercase()
        suggestions.filter { it.lowercase() !in taken }
            .filter { prefix.isEmpty() || it.lowercase().contains(prefix) }
            .filter { it.lowercase() != prefix }
            .take(8)
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PlainTextField(text, onChange, L("Dark fantasy, Jeunesse"))
        Proposals(proposals) { proposal ->
            val entries = committed + proposal
            onChange(entries.joinToString(", ") + if (entries.size < 3) ", " else "")
        }
    }
}

/** A saga name typed, with the reader's sagas proposed. */
@Composable
fun SeriesNameField(text: String, onChange: (String) -> Unit, suggestions: List<String>) {
    val typed = text.trim()
    val proposals = if (suggestions.any { it.equals(typed, ignoreCase = true) }) {
        emptyList()
    } else {
        suggestions.filter { typed.isEmpty() || it.contains(typed, ignoreCase = true) }.take(8)
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PlainTextField(text, onChange, L("Aucune"), capitalization = KeyboardCapitalization.Words)
        Proposals(proposals, onChange)
    }
}

/** `LabeledContent` with a menu: the label on the left, the value in the accent with ⌄. */
@Composable
fun <T> MenuPicker(
    selection: T,
    options: List<T>,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    divider: Boolean = true,
    symbol: ((T) -> String?)? = null,
    rowLabel: @Composable RowScope.() -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val colors = Shiori.colors
    FormRow(divider = divider) {
        rowLabel()
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
            Row(
                Modifier.plainClickable { expanded = true },
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                symbol?.invoke(selection)?.let { Icon(Symbol(it), null, Modifier.size(16.dp), tint = colors.accent) }
                Text(label(selection), style = Shiori.type.body, color = colors.accent)
                Icon(Symbol("chevron.up.chevron.down"), null, Modifier.size(14.dp), tint = colors.accent)
            }
            MenuEntries(
                options.map { option -> MenuEntry.Item(label(option), symbol?.invoke(option), checked = option == selection) { onSelect(option) } },
                expanded,
            ) { expanded = false }
        }
    }
}

/** A form row's label: an icon in grey, then the title. */
@Composable
fun RowScope.RowLabel(title: String, symbol: String) {
    Icon(Symbol(symbol), null, Modifier.size(22.dp), tint = Shiori.colors.secondaryLabel)
    Text(title, style = Shiori.type.body, color = Shiori.colors.label)
}
