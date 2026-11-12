package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.InteractiveStarRating
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** "Lecture terminée": the cover, and the stars to give before marking it read. */
@Composable
fun FinishedBookSheet(book: Book, onDone: (Double?) -> Unit, onCancel: () -> Unit) {
    var rating by remember { mutableDoubleStateOf(0.0) }
    val haptics = LocalHapticFeedback.current
    LaunchedEffect(Unit) { haptics.performHapticFeedback(HapticFeedbackType.Confirm) }
    ShioriSheet(onCancel) { _ ->
        SheetBar(
            leading = { ToolbarIconButton(L("Annuler"), "xmark", onClick = onCancel) },
            trailing = { ToolbarIconButton(L("Marquer lu"), "checkmark", prominent = true) { onDone(if (rating == 0.0) null else rating) } },
        )
        Column(Modifier.fillMaxWidth().padding(bottom = 24.dp).navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.padding(top = 4.dp).shadow(14.dp)) { BookCover(book, 116.dp, showsFormatBadge = false) }
            Text(L("Lecture terminée"), style = Shiori.type.title2, color = Shiori.colors.label, modifier = Modifier.padding(top = 22.dp))
            Text(book.title, style = Shiori.type.headline, color = Shiori.colors.label, textAlign = TextAlign.Center, maxLines = 2, modifier = Modifier.padding(top = 4.dp, start = 24.dp, end = 24.dp))
            Text(L("Qu'en avez-vous pensé ?"), style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel, modifier = Modifier.padding(top = 2.dp))
            Box(Modifier.padding(top = 16.dp)) { InteractiveStarRating(rating, { rating = it }, allowsUnset = false, scale = 1.25f) }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun FinishedBookSheetPreview() = PreviewSurface {
    FinishedBookSheet(DebugFixtures.reading[0], onDone = {}, onCancel = {})
}
