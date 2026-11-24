package com.polyforms.shiori.features.friends

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
import com.polyforms.shiori.features.series.SeriesFriend
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.series.SeriesShelfFilter
import com.polyforms.shiori.features.series.SeriesStatusFilter
import com.polyforms.shiori.features.series.components.pages.SeriesShelfAction
import com.polyforms.shiori.features.series.components.pages.SeriesShelfPage
import com.polyforms.shiori.features.series.components.pages.SeriesStatusMenu
import com.polyforms.shiori.features.series.heldFormat
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScrollAwayBar
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** The most pages asked for, as the reader's own sagas. */
private const val MAX_PAGES = 10

/**
 * A friend's "Séries", connected: the reader's own "Séries" reduced to its cards, two by row, under
 * the filters of their "Livres": the format pills, and the status menu in the corner. Every page is
 * loaded at once, as the reader's sagas are. A card opens the saga as a friend's: where they stand.
 */
@Composable
fun FriendSeriesListScreen(friendId: String, friendName: String, client: FriendsClient = FriendsClient.live) {
    var sagas by remember { mutableStateOf<List<FollowedSeries>>(emptyList()) }
    var loaded by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf(SeriesStatusFilter.ALL) }
    var format by remember { mutableStateOf<BookFormat?>(null) }
    val navigator = currentNavigator

    suspend fun load() {
        errorMessage = null
        try {
            val all = mutableListOf<FriendSaga>()
            var after: String? = null
            for (index in 0 until MAX_PAGES) {
                val (page, more) = client.sagaPage(friendId, null, false, after)
                all += page.filter { new -> all.none { it.id == new.id } }
                val last = page.lastOrNull()
                if (!more || last == null) break
                after = last.id
            }
            sagas = all.map { it.asFollowedSeries }
            loaded = true
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    LaunchedEffect(Unit) { if (!loaded) load() }

    val bar = rememberScrollAwayState()
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).nestedScroll(bar.connection)) {
        SeriesShelfPage(
            upNext = emptyList(),
            releases = emptyList(),
            filters = emptyList(),
            filter = SeriesShelfFilter.ALL,
            series = sagas.filter { saga -> status.keeps(saga) && (format?.let { saga.heldFormat == it } ?: true) },
            isLoading = !loaded && errorMessage == null,
            errorMessage = errorMessage,
            statuses = SeriesStatusFilter.entries,
            selectedStatus = status,
            formats = BookFormat.entries.filter { f -> sagas.any { it.heldFormat == f } },
            selectedFormat = format,
            title = null,
        ) { action ->
            when (action) {
                is SeriesShelfAction.OpenSeries -> navigator.push { SeriesScreen(action.series.seriesId, friend = SeriesFriend(friendId, friendName)) }
                is SeriesShelfAction.SelectStatus -> status = action.status
                is SeriesShelfAction.SelectFormat -> format = action.format
                SeriesShelfAction.Refresh -> load()
                else -> Unit
            }
        }
        if (loaded && sagas.isEmpty()) {
            EmptyState("square.stack", L("Aucune série"), L("Aucune série n'a été ajoutée à cette bibliothèque."))
        }
        // As iOS's scrollAwayBar: the title on the left beside Back, going while the page scrolls
        // down; the status menu, a toolbar item of its own, stays.
        ScrollAwayBar(
            L("Séries"),
            bar,
            showsAccount = false,
            onBack = { navigator.pop() },
            pinned = { SeriesStatusMenu(SeriesStatusFilter.entries, status) { status = it } },
        )
    }
}
