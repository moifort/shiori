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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

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

@Preview(showBackground = true)
@Composable
private fun LibraryShelfPickerPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp)) { LibraryShelfPicker(LibraryShelf.BOOKS, onChange = {}) }
}
