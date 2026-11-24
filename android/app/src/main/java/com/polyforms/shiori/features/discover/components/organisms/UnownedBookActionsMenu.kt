package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ToolbarMenuButton

/**
 * The "…" in the corner of a book nobody here holds, as on a book of the library: what the page
 * does not draw. A cover picked here is the book's for every reader. `extra` is what a page adds
 * over the cover: a discovery's eye, when "Guetter" took its place in the hero.
 */
@Composable
fun UnownedBookActionsMenu(onChooseCover: () -> Unit, extra: List<MenuEntry> = emptyList()) {
    ToolbarMenuButton(
        L("Plus d'actions"),
        "ellipsis",
        extra + MenuEntry.Item(L("Couverture"), "photo", action = onChooseCover),
    )
}

@Preview(showBackground = true)
@Composable
private fun UnownedBookActionsMenuPreview() = PreviewSurface {
    Box(Modifier.padding(16.dp)) { UnownedBookActionsMenu(onChooseCover = {}) }
}
