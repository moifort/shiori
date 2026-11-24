package com.polyforms.shiori.features.news

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.discover.AnnouncedVolumeScreen
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.news.components.pages.PendingReleasePage
import com.polyforms.shiori.features.news.components.pages.PendingReleasePhase
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.reportError

/**
 * A release opened from a list, connected: pushed in the frame of the tap on `PendingReleasePage`,
 * the cover and title the list already had, while it looks the release up among the release
 * watches; then the page it opens in its place — the announced volume, the awaited edition, the
 * author, the narrator. An author's or a narrator's page needs no lookup and is drawn at once.
 */
@Composable
fun UpcomingReleaseScreen(release: UpcomingRelease, lookup: UpcomingReleaseDestination.Lookup = UpcomingReleaseDestination.Lookup.live) {
    var found by remember(release.id) { mutableStateOf(UpcomingReleaseDestination.immediate(release)) }
    var phase by remember(release.id) { mutableStateOf<PendingReleasePhase>(PendingReleasePhase.Loading) }
    suspend fun resolve() {
        phase = PendingReleasePhase.Loading
        try {
            val destination = UpcomingReleaseDestination.of(release, lookup)
            if (destination == null) phase = PendingReleasePhase.Missing else found = destination
        } catch (error: Exception) {
            if (isCancellation(error)) return
            phase = PendingReleasePhase.Failed(reportError(error))
        }
    }
    when (val destination = found) {
        is UpcomingReleaseDestination.Announced -> AnnouncedVolumeScreen(destination.volume.saga, destination.volume.volume)
        is UpcomingReleaseDestination.Awaited -> AwaitedEditionScreen(destination.edition) {}
        is UpcomingReleaseDestination.Author -> AuthorScreen(destination.author.key, destination.author.name)
        is UpcomingReleaseDestination.Narrator -> NarratorScreen(destination.narrator.key, destination.narrator.name)
        null -> {
            LaunchedEffect(release.id) { resolve() }
            Box(Modifier.fillMaxSize()) {
                PendingReleasePage(release, phase) { resolve() }
                ScreenBar()
            }
        }
    }
}
