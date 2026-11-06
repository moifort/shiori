package com.polyforms.shiori.shared.book

import androidx.compose.runtime.Composable
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.components.molecules.RowLabel
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.ShioriSwitch
import androidx.compose.foundation.layout.Spacer
import androidx.compose.ui.Modifier

/** Paper and screen, one switch each; the last one held cannot be switched off. */
@Composable
fun MediaToggles(media: List<BookMedium>, onChange: (List<BookMedium>) -> Unit) {
    BookMedium.entries.forEach { medium ->
        FormRow {
            RowLabel(medium.label, medium.symbol)
            Spacer(Modifier.weight(1f))
            ShioriSwitch(medium in media, { held ->
                val kept = if (held) media + medium else media - medium
                onChange(BookMedium.entries.filter { it in kept })
            }, enabled = media != listOf(medium))
        }
    }
}
