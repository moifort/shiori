package com.polyforms.shiori.features.series.components.organisms

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ShioriAlert
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

enum class SeriesMenuAction { EDIT, DECLARE_VOLUME_COUNT, MERGE, DELETE }

/** A saga's `…`: edit, the volume count of a provisional catalogue, merge, delete. */
@Composable
fun SeriesActionsMenu(isProvisional: Boolean, ownedCount: Int, onAction: (SeriesMenuAction) -> Unit) {
    var confirmDelete by remember { mutableStateOf(false) }
    val entries = buildList {
        add(MenuEntry.Item(L("Modifier"), "pencil") { onAction(SeriesMenuAction.EDIT) })
        if (isProvisional) add(MenuEntry.Item(L("Nombre de tomes"), "number") { onAction(SeriesMenuAction.DECLARE_VOLUME_COUNT) })
        add(MenuEntry.Item(L("Fusionner avec…"), "arrow.triangle.merge") { onAction(SeriesMenuAction.MERGE) })
        add(MenuEntry.Divider)
        add(MenuEntry.Item(L("Supprimer"), "trash", destructive = true) { confirmDelete = true })
    }
    ToolbarMenuButton(L("Plus d'actions"), "ellipsis", entries)
    if (confirmDelete) {
        ShioriAlert(
            L("Supprimer la série ?"),
            L("Les %lld livres de cette série dans votre bibliothèque seront supprimés avec elle, ainsi que votre note. Cette action est définitive.", ownedCount),
            onDismiss = { confirmDelete = false },
            confirm = L("Supprimer"),
            dismissLabel = L("Annuler"),
            destructive = true,
            onConfirm = {
                confirmDelete = false
                onAction(SeriesMenuAction.DELETE)
            },
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun SeriesActionsMenuPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp)) { SeriesActionsMenu(isProvisional = false, ownedCount = 5) {} }
}
