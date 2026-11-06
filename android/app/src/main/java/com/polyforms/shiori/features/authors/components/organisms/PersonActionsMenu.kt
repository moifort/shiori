package com.polyforms.shiori.features.authors.components.organisms

import androidx.compose.runtime.Composable
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ToolbarMenuButton

enum class PersonMenuAction { EDIT, PORTRAIT }

/** A person's `…`: correct their facts, choose their portrait. */
@Composable
fun PersonActionsMenu(onAction: (PersonMenuAction) -> Unit) {
    ToolbarMenuButton(
        L("Plus d'actions"),
        "ellipsis",
        listOf(
            MenuEntry.Item(L("Modifier"), "pencil") { onAction(PersonMenuAction.EDIT) },
            MenuEntry.Item(L("Portrait"), "person.crop.circle") { onAction(PersonMenuAction.PORTRAIT) },
        ),
    )
}
