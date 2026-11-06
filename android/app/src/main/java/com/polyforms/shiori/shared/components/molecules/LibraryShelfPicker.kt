package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.SegmentedControl
import com.polyforms.shiori.shared.components.styles.glass

enum class LibraryShelf {
    BOOKS, SERIES, AUTHORS;

    val label: String
        get() = when (this) {
            BOOKS -> L("Livres")
            SERIES -> L("Séries")
            AUTHORS -> L("Auteurs")
        }
}

/** The shelves a tab is cut into, in a glass capsule at the foot of the screen. */
@Composable
fun LibraryShelfPicker(shelf: LibraryShelf, onChange: (LibraryShelf) -> Unit, shelves: List<LibraryShelf> = LibraryShelf.entries) {
    SegmentedControl(
        shelves,
        shelf,
        { it.label },
        onChange,
        Modifier
            .padding(bottom = 8.dp)
            .glass(CircleShape)
            .padding(4.dp)
            .width((shelves.size * 110).dp),
    )
}
