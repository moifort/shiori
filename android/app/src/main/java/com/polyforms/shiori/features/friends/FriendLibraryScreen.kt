package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.library.components.pages.BookMosaicPage
import com.polyforms.shiori.features.library.components.pages.BookShelfAction
import com.polyforms.shiori.features.library.components.pages.MosaicStatusMenu
import com.polyforms.shiori.features.series.SeriesFriend
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ListSection
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.PushedScrollAwayBar
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/**
 * A friend's "Livres", connected: the reader's own "Livres" — the mosaic cut into months, the
 * status menu, the format pills — over the friend's books. A cover opens the friend's read-only
 * page; the long press puts the book on the reader's pile, or leads to its series or its author.
 */
@Composable
fun FriendLibraryScreen(friendId: String, friendName: String, client: FriendsClient = FriendsClient.live) {
    val model = remember { FriendShelfListModel<FriendBook>({ it.id }, { it.copy(inLibrary = true) }) }
    var status by remember { mutableStateOf<ReadingStatus?>(null) }
    var format by remember { mutableStateOf<BookFormat?>(null) }

    /** The formats the friend holds, kept from the pages shown without a format chosen: the pills. */
    var formats by remember { mutableStateOf<List<BookFormat>>(emptyList()) }
    val navigator = currentNavigator
    val scope = rememberCoroutineScope()
    val query = "${status ?: "all"}-${format ?: "all"}"
    val fetch: suspend (String?) -> Pair<List<FriendBook>, Boolean> = { after -> client.libraryPage(friendId, status, format, after) }

    /** The pills offer every format the books shown so far hold; a format chosen keeps them as they are. */
    fun noteFormats() {
        if (format != null) return
        val held = model.rows.map { it.book.format }.toSet()
        formats = BookFormat.entries.filter { it in held || it in formats }
    }

    LaunchedEffect(query) {
        model.load(query, fetch)
        noteFormats()
    }

    val bar = rememberScrollAwayState()
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).nestedScroll(bar.connection)) {
        BookMosaicPage(
            sections = if (model.loadedQuery == query) ListSection.byMonth(model.rows.map { it.book }) { it.shelvedAt } else emptyList(),
            formats = formats,
            selectedFormat = format,
            selectedStatus = status,
            isLoading = model.loadedQuery != query && model.errorMessage == null,
            errorMessage = if (model.loadedQuery != query || model.rows.isEmpty()) model.errorMessage else null,
            hasMore = model.hasMore,
            loadMoreFailed = model.loadMoreFailed,
            ownedByReader = { book -> model.rows.firstOrNull { it.id == book.id }?.inLibrary == true },
        ) { action ->
            when (action) {
                is BookShelfAction.OpenBook -> model.rows.firstOrNull { it.id == action.book.id }?.let { row ->
                    navigator.push { FriendBookScreen(friendId, row.id, friendName, onAdded = { model.markOwned(row.id) }) }
                }
                is BookShelfAction.SelectStatus -> status = action.status
                is BookShelfAction.SelectFormat -> format = action.format
                is BookShelfAction.Menu -> when (val quick = action.action) {
                    BookQuickAction.Take -> scope.launch {
                        model.take(action.book.id) { client.addBook(friendId, action.book.id, CopiedStatus.TO_READ, action.book.format) }
                    }
                    // The saga as a friend's saga opens: where the friend stands on it.
                    is BookQuickAction.OpenSeries -> navigator.push { SeriesScreen(quick.id, friend = SeriesFriend(friendId, friendName)) }
                    is BookQuickAction.OpenAuthor -> navigator.push { AuthorScreen(quick.key, quick.name) }
                    else -> Unit
                }
                is BookShelfAction.Reached -> {
                    val index = model.rows.indexOfFirst { it.id == action.id }
                    if (model.hasMore && index >= 0 && model.rows.size - index <= 15) {
                        model.loadMore(fetch)
                        noteFormats()
                    }
                }
                BookShelfAction.LoadMore -> {
                    model.loadMore(fetch)
                    noteFormats()
                }
                BookShelfAction.Refresh -> model.load(query, fetch)
                is BookShelfAction.OpenSeries, is BookShelfAction.SelectGenre, BookShelfAction.Share -> Unit
            }
        }
        PushedScrollAwayBar(bar) { MosaicStatusMenu(status) { status = it } }
    }
    model.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { model.addFailed = null }) }
}
