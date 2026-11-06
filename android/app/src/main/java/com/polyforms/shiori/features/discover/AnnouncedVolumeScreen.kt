package com.polyforms.shiori.features.discover

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.components.pages.UpcomingBookPage
import com.polyforms.shiori.features.discover.components.pages.UpcomingStore
import com.polyforms.shiori.features.series.SeriesApi
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.series.components.organisms.amazonURL
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Analytics
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** A saga's volume announced or just out: described on the spot, the saga's bell on it. */
class AnnouncedVolumeViewModel(val opened: DiscoveryVolume) {
    val describer = ReleaseDescriber()
    var added by mutableStateOf(false)
        private set
    var isFollowed by mutableStateOf(true)
        private set
    var sagaVolumes by mutableStateOf<List<SeriesStripItem>>(emptyList())
        private set
    var addFailed by mutableStateOf<String?>(null)

    val shown: Book get() = opened.book.described(describer.description)

    suspend fun describe() = describer.describe(opened.seed)

    suspend fun loadSaga() {
        val series = opened.saga.series
        sagaVolumes = runCatching { BookApi.sagaVolumes(series.seriesId, series.language) }.getOrNull() ?: return
    }

    suspend fun toggleFollowed() {
        val followed = !isFollowed
        isFollowed = followed
        try {
            SeriesApi.setFollowed(opened.saga.series.seriesId, followed)
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
            if (isFollowed == followed) isFollowed = !followed
        }
    }

    /** A recording through the reader's Audible account when it can, else onto the pile. */
    suspend fun add() {
        val series = opened.saga.series
        if (series.isAudio) {
            try {
                SeriesApi.addAudibleVolume(series.seriesId, opened.volume.number)
                Analytics.track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.DISCOVER))
                added = true
                return
            } catch (error: Throwable) {
                if (isCancellation(error)) throw error
                val code = (error as? ApiError)?.domainCode
                if (code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED") reportError(error)
            }
        }
        try {
            DiscoverViewModel.add(opened.draft(shown))
            added = true
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
    }
}

/** A saga's volume to come or just out, as Découvrir, the Home and the saga open it. */
@Composable
fun AnnouncedVolumeScreen(saga: SagaDiscovery, volume: DiscoveredVolume, linksToSaga: Boolean = true) {
    val viewModel = remember(saga.id, volume.number) { AnnouncedVolumeViewModel(DiscoveryVolume(saga, volume)) }
    val navigator = currentNavigator
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { viewModel.describe() }
    LaunchedEffect(Unit) { viewModel.loadSaga() }
    val series = saga.series
    val store = if (series.isAudio) volume.audibleURL?.let { UpcomingStore(it, true) } else UpcomingStore(volume.amazonURL(series.author ?: ""), false)
    val state = when {
        viewModel.added -> BookState.addedToPile
        volume.date?.let { ReleaseDateText.isUpcoming(it) } == true -> null
        else -> BookState.release(volume.date)
    }
    Box(Modifier.fillMaxSize()) {
        UpcomingBookPage(
            viewModel.shown,
            volume.date,
            store,
            isAlerted = viewModel.isFollowed,
            onToggleBell = { scope.launch { viewModel.toggleFollowed() } },
            state = state,
            isAdded = viewModel.added,
            sagaName = series.name,
            sagaVolumes = viewModel.sagaVolumes,
            isDescribing = viewModel.describer.isDescribing,
            onAdd = { viewModel.add() },
            onOpenSaga = { if (linksToSaga) navigator.push { SeriesScreen(series.seriesId) } else navigator.pop() },
            onOpenVolume = { book -> navigator.push { BookScreen(book.id) } },
        )
        ScreenBar()
        GeneratingPillHost(viewModel.describer.isDescribing)
    }
    viewModel.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { viewModel.addFailed = null }) }
}
