package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.friends.FriendSaga
import com.polyforms.shiori.features.series.components.pages.takenAs
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry

/**
 * "+" that puts a friend's book — or the first volume of their saga — on the reader's pile: a
 * spinner while it goes, greyed out on one they already own. It asks how the reader takes the
 * story in, in print or as a recording.
 */
@Composable
fun TakeButton(
    owned: Boolean,
    isAdding: Boolean,
    format: BookFormat,
    addLabel: String = L("Ajouter à ma pile"),
    ownedLabel: String = L("Déjà dans votre bibliothèque"),
    onTake: (BookFormat) -> Unit,
) {
    val colors = Shiori.colors
    var expanded by remember { mutableStateOf(false) }
    if (isAdding) {
        Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) }
        return
    }
    Box {
        Box(
            Modifier.size(32.dp).clip(CircleShape)
                .background((if (owned) colors.tertiaryLabel else colors.accent).copy(alpha = 0.15f), CircleShape)
                .plainClickable(enabled = !owned) { expanded = true }
                .semantics { contentDescription = if (owned) ownedLabel else addLabel },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Symbol("plus"), null, Modifier.size(14.dp), tint = if (owned) colors.tertiaryLabel else colors.accent)
        }
        MenuEntries(format.takenAs.map { taken -> MenuEntry.Item(taken.label, taken.symbol) { onTake(taken) } }, expanded) { expanded = false }
    }
}

/** What its first volume is, which is the one a "+" takes. */
val FriendSaga.takenFormat: BookFormat
    get() = volumes.firstOrNull()?.format ?: if (isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
