package com.polyforms.shiori.features.discover

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.components.pages.BellConfirmation
import com.polyforms.shiori.features.discover.components.pages.UpcomingBookPage
import com.polyforms.shiori.features.discover.components.pages.UpcomingStore
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** An edition awaited: described on the spot, with the reader's own copy's saga when it has one. */
class AwaitedEditionViewModel(val edition: AwaitedEdition) {
    val describer = ReleaseDescriber()
    var sagaVolumes by mutableStateOf<List<SeriesStripItem>>(emptyList())
        private set
    private var series by mutableStateOf<SeriesMembership?>(null)
    var added by mutableStateOf(false)
        private set
    var addFailed by mutableStateOf<String?>(null)

    val shown: Book
        get() {
            val book = edition.cover.described(describer.description)
            return if (book.series == null) book.copy(series = series) else book
        }

    suspend fun describe() = describer.describe(edition.seed)

    /** The reader's own copy it is awaited of, for its saga. */
    suspend fun loadSaga() {
        val bookId = edition.bookId ?: return
        val book = runCatching { BookApi.book(bookId) }.getOrNull() ?: return
        val membership = book.series ?: return
        val volumes = runCatching { BookApi.sagaVolumes(membership.id, book.language) }.getOrNull() ?: return
        series = membership
        sagaVolumes = volumes
    }

    suspend fun add() {
        try {
            DiscoverViewModel.add(edition.draft(shown))
            added = true
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
    }
}

/** An edition the reader awaits, as Découvrir, a book page and the wishlist open it. */
@Composable
fun AwaitedEditionScreen(edition: AwaitedEdition, onStop: () -> Unit) {
    val viewModel = remember(edition.id) { AwaitedEditionViewModel(edition) }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.describe() }
    LaunchedEffect(Unit) { viewModel.loadSaga() }
    val shown = viewModel.shown
    val state = when {
        viewModel.added -> BookState.addedToPile
        edition.state == AwaitedState.ANNOUNCED && edition.date?.let { ReleaseDateText.isUpcoming(it) } == true -> null
        else -> BookState(edition.stateLine, edition.stateTint ?: com.polyforms.shiori.shared.SystemTint.GRAY)
    }
    Box(Modifier.fillMaxSize()) {
        UpcomingBookPage(
            shown,
            edition.date,
            edition.storeURL?.let { UpcomingStore(it, edition.format == ReleaseFormat.AUDIOBOOK) },
            isAlerted = true,
            onToggleBell = {
                onStop()
                navigator.pop()
            },
            bellConfirmation = BellConfirmation(L("Ne plus suivre ce livre ?"), L("Vous ne serez plus prévenu de sa sortie."), L("Ne plus suivre")),
            state = state,
            isOut = edition.state == AwaitedState.AVAILABLE,
            isAdded = if (edition.isAddable) viewModel.added else null,
            leadingTiles = if (edition.title == edition.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), edition.originalTitle, isWide = true)),
            sagaName = shown.series?.name,
            sagaVolumes = viewModel.sagaVolumes,
            currentVolumeId = edition.bookId,
            isDescribing = viewModel.describer.isDescribing,
            onAdd = { viewModel.add() },
            onOpenSaga = { shown.series?.id?.let { id -> navigator.push { SeriesScreen(id) } } },
            onOpenVolume = { book -> navigator.push { BookScreen(book.id) } },
        )
        ScreenBar()
        GeneratingPillHost(viewModel.describer.isDescribing)
    }
    viewModel.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { viewModel.addFailed = null }) }
}
