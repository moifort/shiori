package com.polyforms.shiori.features.listening

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.features.listening.components.pages.PlayerBackdrop

/**
 * Hands the app's one player and where it stands on screen to everything under it: the tabs,
 * whose play buttons drive it, and the tab bar, whose accessory shows it.
 */
@Composable
fun PlayerHost(content: @Composable () -> Unit) {
    val context: Context = LocalContext.current
    val player = remember { AudiblePlayers.app(context) }
    val presentation = remember { PlayerPresentation() }
    CompositionLocalProvider(LocalAudiblePlayer provides player, LocalPlayerPresentation provides presentation, content = content)
}

/**
 * The full-screen player over the tabs, while it is open. Not a system sheet: pulled down, it
 * follows the thumb whole, then shrinks into its pill.
 *
 * `onOpenBook` gets the book the player's three dots asked for, once the player has closed: the
 * tab in front pushes its page, with the usual Back button, the title still playing in the
 * capsule over the tab bar, rather than in a sheet of its own.
 */
@Composable
fun PlayerOverlay(onOpenBook: (String) -> Unit) {
    val player = LocalAudiblePlayer.current ?: return
    val presentation = LocalPlayerPresentation.current ?: return
    if (!presentation.isOpen) return
    PlayerSheet(
        pillFrame = presentation.pillFrame,
        coverURL = player.title?.coverURL,
        onClosed = {
            presentation.isOpen = false
            presentation.pendingBook?.let(onOpenBook)
            presentation.pendingBook = null
        },
        backdrop = { PlayerBackdrop(player.title?.coverURL) },
        pill = { PlayerAccessoryScreen(player) {} },
    ) {
        PlayerScreen(player) { presentation.pendingBook = it }
    }
}
