package com.polyforms.shiori.shared.components.molecules

import com.polyforms.shiori.shared.components.styles.ShioriTheme
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import kotlinx.coroutines.delay
import java.util.UUID

/**
 * A brief word in the middle of the screen once something is done: a large symbol over a short
 * line, on a dark translucent square. It shows, holds, and fades by itself; nothing in it can be
 * tapped. Android draws no backdrop blur, so the square is denser than iOS's.
 */
@Composable
fun ConfirmationHUD(symbol: String, label: String, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(30.dp)
    ShioriTheme(dark = true) {
        // Drawn dark in either appearance, as iOS forces `.colorScheme(.dark)` on it.
        Column(
            modifier
                .size(190.dp)
                .background(Color(0xE0262628), shape)
                .background(Color.White.copy(alpha = 0.08f), shape)
                .border(0.5.dp, Color.White.copy(alpha = 0.22f), shape)
                .clearAndSetSemantics { contentDescription = label },
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Symbol(symbol), null, Modifier.height(64.dp).size(60.dp), tint = Color.White)
            Text(
                label,
                style = Shiori.type.callout.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 18.dp),
            )
        }
    }
}

/** What the HUD says, and with which symbol. */
data class Confirmation(val symbol: String, val label: String, val id: String = UUID.randomUUID().toString()) {
    companion object {
        /** How long the HUD holds before it fades, in milliseconds. */
        const val HOLD_MILLIS = 1600L

        /** The book went onto the shelf, whatever its status. */
        val addedToLibrary get() = Confirmation("book", L("Ajouté à la bibliothèque"))

        /** The book went onto the wishlist. */
        val addedToWishlist get() = Confirmation("bookmark", L("Ajouté à la liste d'envies"))

        /** An edition is awaited: it shows on the wishlist among those awaited. */
        val awaited get() = Confirmation("binoculars", L("Ajouté à la liste d'envies"))
    }
}

/** Shows `confirmation`'s HUD over the screen while it is set, and clears it after a moment. */
@Composable
fun BoxScope.ConfirmationHost(confirmation: Confirmation?, onCleared: () -> Unit) {
    var shown by remember { mutableStateOf(confirmation) }
    if (confirmation != null) shown = confirmation
    LaunchedEffect(confirmation?.id) {
        if (confirmation == null) return@LaunchedEffect
        delay(Confirmation.HOLD_MILLIS)
        onCleared()
    }
    AnimatedVisibility(
        confirmation != null,
        Modifier.align(Alignment.Center),
        enter = scaleIn(spring(), initialScale = 0.85f) + fadeIn(),
        exit = fadeOut(tween(300)),
    ) {
        shown?.let { ConfirmationHUD(it.symbol, it.label) }
    }
}

@Preview(showBackground = true)
@Composable
private fun ConfirmationHUDPreview() = PreviewSurface(dark = true) {
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFF3F51B5), Color.Black))), contentAlignment = Alignment.Center) {
        ConfirmationHUD(Confirmation.addedToLibrary.symbol, Confirmation.addedToLibrary.label)
    }
}
