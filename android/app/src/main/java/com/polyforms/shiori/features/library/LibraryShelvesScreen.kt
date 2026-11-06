package com.polyforms.shiori.features.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.library.components.pages.LibraryShelvesAction
import com.polyforms.shiori.features.library.components.pages.LibraryShelvesPage
import com.polyforms.shiori.features.narrators.NarratorDestination
import com.polyforms.shiori.features.series.SeriesRequest
import com.polyforms.shiori.features.series.SeriesShelfFilter
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator

/** The Library's shelves, or a genre's, connected: opens whatever they link to. */
@Composable
fun LibraryShelvesScreen(
    genre: BookGenre? = null,
    client: LibraryClient = LibraryClient.live,
    libraryRequest: LibraryRequest? = null,
    seriesRequest: SeriesRequest? = null,
    onRequestTaken: () -> Unit = {},
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(genre) { LibraryShelvesViewModel(client, scope, genre) }
    val navigator = currentNavigator
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, client) }
    val quick = rememberBookQuickActions(client, ::open)

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    LaunchedEffect(libraryRequest) {
        val asked = libraryRequest ?: return@LaunchedEffect
        onRequestTaken()
        navigator.popToRoot()
        LibraryDestination.of(asked)?.let(::open)
    }
    LaunchedEffect(seriesRequest) {
        val asked = seriesRequest ?: return@LaunchedEffect
        onRequestTaken()
        navigator.popToRoot()
        open(LibraryDestination.SeriesShelf(if (asked.state == SeriesState.IN_PROGRESS) SeriesShelfFilter.IN_PROGRESS else SeriesShelfFilter.ALL))
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        LibraryShelvesPage(
            viewModel.shelves,
            viewModel.formats,
            viewModel.view.format,
            genre,
            viewModel.subgenres,
            viewModel.view.subgenre,
            viewModel.isLoading,
            viewModel.errorMessage,
        ) { action ->
            when (action) {
                is LibraryShelvesAction.OpenBook -> open(LibraryDestination.BookPage(action.book))
                is LibraryShelvesAction.OpenShelf -> open(LibraryDestination.Shelf(action.shelf, viewModel.view, formats = viewModel.formats))
                LibraryShelvesAction.OpenSeriesShelf -> open(LibraryDestination.SeriesShelf())
                is LibraryShelvesAction.OpenSeries -> open(LibraryDestination.Series(action.series.seriesId))
                LibraryShelvesAction.OpenAuthors -> open(LibraryDestination.Authors)
                is LibraryShelvesAction.OpenAuthor -> open(LibraryDestination.Author(AuthorDestination(action.author)))
                LibraryShelvesAction.OpenNarrators -> open(LibraryDestination.Narrators)
                is LibraryShelvesAction.OpenNarrator -> open(LibraryDestination.Narrator(NarratorDestination(action.narrator.key, action.narrator.name)))
                LibraryShelvesAction.OpenWishlist -> open(LibraryDestination.Wishlist)
                is LibraryShelvesAction.OpenGenre -> open(LibraryDestination.Genre(action.genre))
                is LibraryShelvesAction.SelectFormat -> viewModel.select(action.format)
                is LibraryShelvesAction.SelectSubgenre -> viewModel.select(action.subgenre)
                is LibraryShelvesAction.Menu -> quick(action.book, action.action)
                LibraryShelvesAction.Refresh -> viewModel.load()
            }
        }
        if (genre != null) ScreenBar()
    }
}
