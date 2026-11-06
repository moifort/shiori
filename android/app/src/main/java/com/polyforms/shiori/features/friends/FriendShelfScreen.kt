package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.friends.components.pages.FriendLibraryPage
import com.polyforms.shiori.features.friends.components.pages.FriendSeriesListPage
import com.polyforms.shiori.features.friends.components.pages.FriendShelfAction
import com.polyforms.shiori.features.library.LibraryMode
import com.polyforms.shiori.features.series.SeriesFriend
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.LibraryShelf
import com.polyforms.shiori.shared.components.molecules.LibraryShelfPicker
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ToolbarFilterMenu
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/**
 * A friend's paged shelf — their books or their sagas — with the "+" that takes a row onto the
 * reader's own. The query the rows answer is kept: until a new one's answer arrives, the page
 * shows a spinner rather than the last rows cut the new way.
 */
class FriendShelfListModel<Row>(private val idOf: (Row) -> String, private val owning: (Row) -> Row) {
    var rows by mutableStateOf<List<Row>>(emptyList())
        private set
    var hasMore by mutableStateOf(false)
        private set
    var loadedQuery by mutableStateOf<String?>(null)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var loadMoreFailed by mutableStateOf(false)
        private set
    var adding by mutableStateOf<Set<String>>(emptySet())
        private set
    var addFailed by mutableStateOf<String?>(null)

    suspend fun load(query: String, fetch: suspend (String?) -> Pair<List<Row>, Boolean>) {
        errorMessage = null
        loadMoreFailed = false
        try {
            val (page, more) = fetch(null)
            rows = page
            hasMore = more
            loadedQuery = query
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    suspend fun loadMore(fetch: suspend (String?) -> Pair<List<Row>, Boolean>) {
        loadMoreFailed = false
        try {
            val (page, more) = fetch(rows.lastOrNull()?.let(idOf))
            val known = rows.map(idOf).toSet()
            rows = rows + page.filter { idOf(it) !in known }
            hasMore = more
        } catch (error: Throwable) {
            if (!isCancellation(error)) {
                reportError(error)
                loadMoreFailed = true
            }
        }
    }

    /** Takes a row onto the reader's shelf; the row then says it is theirs. */
    suspend fun take(rowId: String, add: suspend () -> Unit) {
        adding = adding + rowId
        try {
            add()
            markOwned(rowId)
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
        adding = adding - rowId
    }

    fun markOwned(rowId: String) {
        rows = rows.map { if (idOf(it) == rowId) owning(it) else it }
    }
}

/**
 * A friend's library — or the reader's own, previewed — laid out as the Library tab: the capsule
 * at the foot switches between the books and the sagas.
 */
@Composable
fun FriendShelfScreen(friendId: String, friendName: String, isPreview: Boolean = false, client: FriendsClient = FriendsClient.live) {
    var shelf by remember { mutableStateOf(LibraryShelf.BOOKS) }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        if (shelf == LibraryShelf.SERIES) {
            FriendSeriesListScreen(friendId, friendName, isPreview, client)
        } else {
            FriendLibraryScreen(friendId, friendName, isPreview, client)
        }
        Box(Modifier.align(Alignment.BottomCenter).navigationBarsPadding()) {
            LibraryShelfPicker(shelf, { shelf = it }, listOf(LibraryShelf.BOOKS, LibraryShelf.SERIES))
        }
    }
}

/** A friend's whole library, connected: a page per view and filter, the "+" onto the pile. */
@Composable
fun FriendLibraryScreen(friendId: String, friendName: String, isPreview: Boolean = false, client: FriendsClient = FriendsClient.live) {
    val model = remember { FriendShelfListModel<FriendBook>({ it.id }, { it.copy(inLibrary = true) }) }
    var mode by remember { mutableStateOf(LibraryMode.ALL) }
    var status by remember { mutableStateOf<ReadingStatus?>(null) }
    val navigator = currentNavigator
    val query = "$mode-${status ?: "all"}"
    val fetch: suspend (String?) -> Pair<List<FriendBook>, Boolean> = { after -> client.libraryPage(friendId, status, mode == LibraryMode.FAVORITES, after) }
    LaunchedEffect(query) { model.load(query, fetch) }

    Box(Modifier.fillMaxSize()) {
        FriendLibraryPage(
            model.rows,
            mode,
            status,
            isWaiting = model.loadedQuery != query && model.errorMessage == null,
            loadFailed = if (model.loadedQuery != query || model.rows.isEmpty()) model.errorMessage else null,
            hasMore = model.hasMore,
            loadMoreFailed = model.loadMoreFailed,
            adding = model.adding,
            isPreview = isPreview,
        ) { action ->
            when (action) {
                is FriendShelfAction.Open -> navigator.push {
                    FriendBookScreen(friendId, action.row.id, friendName, onAdded = { model.markOwned(action.row.id) })
                }
                is FriendShelfAction.Take -> model.take(action.row.id) { client.addBook(friendId, action.row.id, CopiedStatus.TO_READ, action.format) }
                FriendShelfAction.LoadMore -> model.loadMore(fetch)
                FriendShelfAction.Refresh -> model.load(query, fetch)
            }
        }
        ScreenBar(L("Bibliothèque")) {
            LibraryMode.entries.forEach { item ->
                ToolbarIconButton(item.label, item.icon, prominent = mode == item) { mode = item }
            }
            ToolbarFilterMenu(
                status?.symbol ?: "tray.full",
                status?.shelfTitle ?: L("Tous"),
                listOf(MenuEntry.Item(L("Tous"), "tray.full", checked = status == null) { status = null }) +
                    listOf(ReadingStatus.READING, ReadingStatus.TO_READ, ReadingStatus.READ, ReadingStatus.DROPPED).map { s ->
                        MenuEntry.Item(s.shelfTitle, s.symbol, checked = status == s) { status = s }
                    },
            )
        }
    }
    model.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { model.addFailed = null }) }
}

/** A friend's sagas, connected: a page per view and filter, the "+" onto the pile. */
@Composable
fun FriendSeriesListScreen(friendId: String, friendName: String, isPreview: Boolean = false, client: FriendsClient = FriendsClient.live) {
    val model = remember { FriendShelfListModel<FriendSaga>({ it.id }, { it.copy(inLibrary = true) }) }
    var mode by remember { mutableStateOf(LibraryMode.ALL) }
    var state by remember { mutableStateOf<SeriesState?>(null) }
    val navigator = currentNavigator
    val query = "$mode-${state ?: "all"}"
    val fetch: suspend (String?) -> Pair<List<FriendSaga>, Boolean> = { after -> client.sagaPage(friendId, state, mode == LibraryMode.FAVORITES, after) }
    LaunchedEffect(query) { model.load(query, fetch) }

    Box(Modifier.fillMaxSize()) {
        FriendSeriesListPage(
            model.rows,
            mode,
            state,
            isWaiting = model.loadedQuery != query && model.errorMessage == null,
            loadFailed = if (model.loadedQuery != query || model.rows.isEmpty()) model.errorMessage else null,
            hasMore = model.hasMore,
            loadMoreFailed = model.loadMoreFailed,
            adding = model.adding,
            isPreview = isPreview,
        ) { action ->
            when (action) {
                // Where the saga stands is the friend's; previewed, the reader's own opens.
                is FriendShelfAction.Open -> navigator.push {
                    SeriesScreen(action.row.seriesId, friend = if (isPreview) null else SeriesFriend(friendId, friendName))
                }
                is FriendShelfAction.Take -> {
                    val first = action.row.volumes.firstOrNull() ?: return@FriendSeriesListPage
                    model.take(action.row.id) { client.addBook(friendId, first.id, CopiedStatus.TO_READ, action.format) }
                }
                FriendShelfAction.LoadMore -> model.loadMore(fetch)
                FriendShelfAction.Refresh -> model.load(query, fetch)
            }
        }
        ScreenBar(L("Séries")) {
            LibraryMode.seriesViews.forEach { item ->
                ToolbarIconButton(item.label, item.icon, prominent = mode == item) { mode = item }
            }
            ToolbarFilterMenu(
                state?.symbol ?: "tray.full",
                state?.shelfTitle ?: L("Toutes"),
                listOf(MenuEntry.Item(L("Toutes"), "tray.full", checked = state == null) { state = null }) +
                    listOf(SeriesState.IN_PROGRESS, SeriesState.NOT_STARTED, SeriesState.COMPLETE).map { s ->
                        MenuEntry.Item(s.shelfTitle, s.symbol, checked = state == s) { state = s }
                    },
            )
        }
    }
    model.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { model.addFailed = null }) }
}
