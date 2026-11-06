package com.polyforms.shiori.features.book.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.InteractiveStarRating
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriSheet

enum class RatingSubject { BOOK, SERIES }

/** A small sheet of five stars: rating a book marks it read. */
@Composable
fun RatingPromptSheet(
    current: Double?,
    onDismiss: () -> Unit,
    subject: RatingSubject = RatingSubject.BOOK,
    onRemove: (() -> Unit)? = null,
    onRate: (Double) -> Unit,
) {
    var rating by remember { mutableDoubleStateOf(current ?: 0.0) }
    val title = when {
        current != null -> L("Modifier la note")
        subject == RatingSubject.BOOK -> L("Noter ce livre")
        else -> L("Noter cette série")
    }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(title, leading = { ToolbarIconButton(L("Annuler"), "xmark") { dismiss() } })
        Column(
            Modifier.fillMaxWidth().padding(16.dp).navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (current == null && subject == RatingSubject.BOOK) {
                Text(L("Noter un livre le marque comme lu."), style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel, textAlign = TextAlign.Center)
            }
            InteractiveStarRating(rating, { stars ->
                rating = stars
                if (stars > 0 && stars != current) onRate(stars)
            }, allowsUnset = false)
            if (current != null && onRemove != null) {
                ShioriButton(L("Retirer la note"), kind = ButtonKind.PLAIN, destructive = true) { onRemove() }
            }
        }
    }
}
