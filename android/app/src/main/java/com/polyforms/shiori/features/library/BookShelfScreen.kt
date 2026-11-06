package com.polyforms.shiori.features.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.library.components.pages.BookMosaicPage
import com.polyforms.shiori.features.library.components.pages.BookShelfAction
import com.polyforms.shiori.features.library.components.pages.BookShelfPage
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ToolbarFilterMenu
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.platform.shareText
import kotlinx.coroutines.launch

/** One Library shelf, connected; every book as a mosaic. */
@Composable
fun BookShelfScreen(
    shelf: BookShelf,
    view: ShelvesView = ShelvesView(),
    status: ReadingStatus? = null,
    formats: List<BookFormat> = emptyList(),
    client: LibraryClient = LibraryClient.live,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { BookShelfViewModel(client, scope, shelf, view, status, formats) }
    val navigator = currentNavigator
    val context = LocalContext.current
    var isPreparingShare by remember { mutableStateOf(false) }
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, client) }
    val quick = rememberBookQuickActions(client, ::open)

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load(keepingDepth = true) } }

    val handle: suspend (BookShelfAction) -> Unit = { action ->
        when (action) {
            is BookShelfAction.OpenBook -> open(LibraryDestination.BookPage(action.book))
            is BookShelfAction.OpenSeries -> open(LibraryDestination.Series(action.series.seriesId))
            is BookShelfAction.SelectStatus -> viewModel.select(action.status)
            is BookShelfAction.SelectGenre -> viewModel.select(action.genre)
            is BookShelfAction.SelectFormat -> viewModel.select(action.format)
            is BookShelfAction.Menu -> quick(action.book, action.action)
            is BookShelfAction.Reached -> viewModel.prefetchIfNeeded(action.id)
            BookShelfAction.LoadMore -> viewModel.loadMore()
            BookShelfAction.Refresh -> viewModel.load()
            BookShelfAction.Share -> {
                isPreparingShare = true
                viewModel.shareMessage()?.let { context.shareText(it) }
                isPreparingShare = false
            }
        }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        if (shelf == BookShelf.ALL) {
            BookMosaicPage(
                viewModel.sections,
                viewModel.shownFormats,
                viewModel.query.view.format,
                viewModel.query.status,
                viewModel.isLoading,
                viewModel.errorMessage,
                viewModel.hasMore,
                viewModel.loadMoreFailed,
                handle,
            )
        } else {
            BookShelfPage(
                shelf,
                viewModel.sections,
                viewModel.lovedSeries,
                viewModel.statusPills,
                viewModel.query.status,
                viewModel.genrePills,
                viewModel.query.view.genre,
                viewModel.shownFormats,
                viewModel.query.view.format,
                viewModel.isLoading,
                viewModel.errorMessage,
                viewModel.hasMore,
                viewModel.loadMoreFailed,
                handle,
            )
        }
        ScreenBar {
            if (shelf == BookShelf.ALL) {
                val selected = viewModel.query.status
                ToolbarFilterMenu(
                    selected?.symbol ?: "tray.full",
                    selected?.shelfTitle ?: L("Tous"),
                    listOf(MenuEntry.Item(L("Tous"), "tray.full", checked = selected == null) { viewModel.select(null as ReadingStatus?) }) +
                        listOf(ReadingStatus.READING, ReadingStatus.TO_READ, ReadingStatus.READ, ReadingStatus.DROPPED).map { status ->
                            MenuEntry.Item(status.shelfTitle, status.symbol, checked = selected == status) { viewModel.select(status) }
                        },
                )
            }
            if (shelf == BookShelf.LOVED && (viewModel.sections.isNotEmpty() || viewModel.lovedSeries.isNotEmpty())) {
                if (isPreparingShare) {
                    CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                } else {
                    ToolbarIconButton(L("Partager"), "square.and.arrow.up") { scope.launch { handle(BookShelfAction.Share) } }
                }
            }
        }
    }
}

/** Every book of the Library, as a mosaic. */
@Composable
fun BookMosaicScreen(view: ShelvesView = ShelvesView(), formats: List<BookFormat> = emptyList(), client: LibraryClient = LibraryClient.live) =
    BookShelfScreen(BookShelf.ALL, view, formats = formats, client = client)
