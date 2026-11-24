package com.polyforms.shiori.features.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.library.components.pages.PileAction
import com.polyforms.shiori.features.library.components.pages.PilePage
import com.polyforms.shiori.features.series.SeriesClient
import com.polyforms.shiori.features.series.SeriesShelfViewModel
import com.polyforms.shiori.features.series.keeps
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.features.discover.AnnouncedVolumeScreen
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** The pile to read, connected. */
@Composable
fun PileScreen(view: ShelvesView = ShelvesView(), client: LibraryClient = LibraryClient.live, seriesClient: SeriesClient = SeriesClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { PileViewModel(client, scope, view) }
    val series = remember { SeriesShelfViewModel(seriesClient, scope) }
    val navigator = currentNavigator
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, client) }
    val quick = rememberBookQuickActions(client, ::open)

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { series.loadOnAppear() }
    LaunchedEffect(Unit) {
        DataChanges.notices.collect {
            scope.launch { viewModel.load() }
            scope.launch { series.load() }
        }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        PilePage(
            viewModel.pile,
            viewModel.wished.map { PosterRowItem(it, viewModel.wishlist.caption(it)) },
            series.upNext.filter { viewModel.view.keeps(it) },
            viewModel.shownGenres,
            viewModel.view.genre,
            viewModel.isLoading,
            viewModel.errorMessage,
        ) { action ->
            when (action) {
                is PileAction.OpenBook -> open(LibraryDestination.BookPage(action.book))
                is PileAction.OpenSeries -> open(LibraryDestination.Series(action.series.seriesId))
                is PileAction.SelectGenre -> viewModel.select(action.genre)
                is PileAction.Menu -> quick(action.book, action.action)
                is PileAction.OpenVolume -> navigator.push { AnnouncedVolumeScreen(action.volume.saga, action.volume.volume) }
                PileAction.OpenWishlist -> open(LibraryDestination.Wishlist)
                is PileAction.DropWished -> viewModel.dropWished(action.book)
                is PileAction.OpenWished -> {
                    val edition = viewModel.wishlist.edition(action.book)
                    // The wish's own page comes with the books-not-held port; until then, the list.
                    if (edition != null) {
                        navigator.push { AwaitedEditionScreen(edition, onStop = { navigator.pop() }) }
                    } else {
                        open(LibraryDestination.Wishlist)
                    }
                }
                PileAction.Refresh -> {
                    scope.launch { series.load() }
                    viewModel.load()
                }
            }
        }
        ScreenBar()
        viewModel.actionError?.let { message ->
            ShioriAlert(L("Action impossible"), message, onDismiss = { viewModel.actionError = null })
        }
    }
}
