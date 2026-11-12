package com.polyforms.shiori.features.authors.components.organisms

import androidx.compose.runtime.Composable
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ToolbarMenuButton
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

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

@Preview(showBackground = true)
@Composable
private fun PersonActionsMenuPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp)) { PersonActionsMenu {} }
}
