package com.polyforms.shiori.features.listening

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned

/**
 * Where the player stands on screen: whether its sheet is open, and where its pill sits over the
 * tab bar, for the sheet to grow out of it and shrink back into it.
 */
class PlayerPresentation {
    var isOpen by mutableStateOf(false)

    /** The pill's frame in the root; empty while no pill is drawn. */
    var pillFrame by mutableStateOf(Rect.Zero)

    /** The book the player's three dots asked for, pushed once the player has closed. */
    var pendingBook: String? = null
}

/** Set once for the whole app by `ContentView`, beside [LocalAudiblePlayer]. */
val LocalPlayerPresentation = staticCompositionLocalOf<PlayerPresentation?> { null }

/**
 * The title playing, floating over the tab bar as Music's capsule does, and sliding between the
 * chosen tab and the scanner once the bar is folded. Null while nothing plays, which frees the
 * slot.
 */
@Composable
fun playerAccessory(): (@Composable () -> Unit)? {
    val player = LocalAudiblePlayer.current ?: return null
    val presentation = LocalPlayerPresentation.current ?: return null
    if (player.title == null) return null
    return {
        PlayerAccessoryScreen(
            player,
            // Under the player while it is open, so the sheet lands on it.
            Modifier
                .alpha(if (presentation.isOpen) 0f else 1f)
                .onGloballyPositioned { presentation.pillFrame = it.boundsInRoot() },
        ) { presentation.isOpen = true }
    }
}
