package com.polyforms.shiori.features.listening

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.polyforms.shiori.features.listening.components.organisms.PlayerAccessory
import com.polyforms.shiori.features.listening.components.organisms.PlayerAccessoryItem
import com.polyforms.shiori.features.listening.components.pages.PlayerAction
import com.polyforms.shiori.features.listening.components.pages.PlayerPage
import com.polyforms.shiori.features.listening.components.pages.PlayerPageItem
import com.polyforms.shiori.shared.isCancellation

/** The full-screen player, on the app's one [AudiblePlayer]. */
@Composable
fun PlayerScreen(player: AudiblePlayer, onOpenBook: (String) -> Unit) {
    val closePlayer = LocalClosePlayer.current
    // What follows the title playing, asked again whenever it changes.
    var queue by remember { mutableStateOf<List<ListeningQueueEntry>?>(null) }
    val item = playerPageItem(player, queue)
    if (item == null) {
        // Stopped from the notification while open: nothing left to show.
        Box(Modifier.fillMaxSize().background(Color.Black))
        LaunchedEffect(Unit) { closePlayer?.invoke() }
        return
    }
    PlayerPage(item) { action ->
        when (action) {
            PlayerAction.TogglePlay -> player.togglePlayPause()
            is PlayerAction.Skip -> player.skip(action.seconds)
            PlayerAction.PreviousChapter -> player.previousChapter()
            PlayerAction.NextChapter -> player.nextChapter()
            is PlayerAction.Seek -> player.seek(action.position)
            is PlayerAction.Sleep -> player.toggleSleepTimer(action.minutes)
            PlayerAction.OpenBook -> player.title?.bookID?.let {
                onOpenBook(it)
                closePlayer?.invoke()
            }
            is PlayerAction.Play -> player.play(action.title)
        }
    }
    LaunchedEffect(player.title?.asin) {
        queue = null
        queue = try {
            player.upNext()
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            // The queue is a convenience: it stays empty rather than getting in the way of
            // what plays.
            emptyList()
        }
    }
}

/**
 * The accessory over the tab bar, on the app's one [AudiblePlayer]. Drawn only while a title is
 * playing or paused.
 */
@Composable
fun PlayerAccessoryScreen(player: AudiblePlayer, modifier: Modifier = Modifier, onOpen: () -> Unit) {
    val item = playerAccessoryItem(player) ?: return
    PlayerAccessory(
        item,
        modifier,
        onOpen = onOpen,
        onTogglePlay = { player.togglePlayPause() },
        onSkipBack = { player.skip(-AudiblePlayer.SKIP_INTERVAL) },
    )
}

fun playerPageItem(player: AudiblePlayer, queue: List<ListeningQueueEntry>? = null): PlayerPageItem? {
    val title = player.title ?: return null
    return PlayerPageItem(
        title = title.title,
        subtitle = title.subtitle,
        coverURL = title.coverURL,
        progress = player.progress,
        isPlaying = player.isPlaying,
        isLoading = player.phase == AudiblePlayer.Phase.Loading,
        failure = (player.phase as? AudiblePlayer.Phase.Failed)?.message,
        sleepMinutes = player.sleepTimer?.minutes,
        hasBook = title.bookID != null,
        queue = queue,
    )
}

fun playerAccessoryItem(player: AudiblePlayer): PlayerAccessoryItem? {
    val title = player.title ?: return null
    val line = when (val phase = player.phase) {
        AudiblePlayer.Phase.Loading -> if (player.duration > 0) ListeningText.accessoryLine(player.progress) else title.subtitle
        AudiblePlayer.Phase.Ready, AudiblePlayer.Phase.Waiting -> ListeningText.accessoryLine(player.progress)
        is AudiblePlayer.Phase.Failed -> phase.message
    }
    val settled = player.phase == AudiblePlayer.Phase.Ready || player.phase == AudiblePlayer.Phase.Waiting
    return PlayerAccessoryItem(
        title = title.title,
        line = line,
        shortLine = if (settled) ListeningText.shortLine(player.progress) else null,
        coverURL = title.coverURL,
        isPlaying = player.isPlaying,
        isLoading = player.phase == AudiblePlayer.Phase.Loading,
    )
}
