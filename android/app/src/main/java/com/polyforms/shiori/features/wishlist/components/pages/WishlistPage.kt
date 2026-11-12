package com.polyforms.shiori.features.wishlist.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.library.shelfLabel
import com.polyforms.shiori.features.series.components.organisms.SeriesReleaseCard
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.Wishlist
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface WishlistAction {
    data class OpenEdition(val edition: AwaitedEdition) : WishlistAction
    data class ChooseWish(val wish: Wish) : WishlistAction
    data class SelectFormat(val format: BookFormat?) : WishlistAction
    data object Refresh : WishlistAction
}

/** An awaited edition as a release card draws it. */
val AwaitedEdition.volume: DiscoveredVolume
    get() = DiscoveredVolume(0, title, date, null, coverURL, if (format == ReleaseFormat.AUDIOBOOK) storeURL else null)

/** The wishlist: coming releases, what is out, the friends' and Découvrir's picks, the scans. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WishlistPage(
    wishlist: Wishlist,
    formats: List<BookFormat>,
    selectedFormat: BookFormat?,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (WishlistAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: WishlistAction) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }

    @Composable
    fun Rail(title: String, items: List<PosterRowItem>) {
        if (items.isEmpty()) return
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            RowHeader(title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
            PosterRow(items) {}
        }
    }
    fun editions(list: List<AwaitedEdition>, caption: (AwaitedEdition) -> String) =
        list.map { edition -> PosterRowItem(edition.cover, caption(edition)) { send(WishlistAction.OpenEdition(edition)) } }
    fun wishes(list: List<Wish>, caption: (Wish) -> String) =
        list.map { wish -> PosterRowItem(wish.cover, caption(wish)) { send(WishlistAction.ChooseWish(wish)) } }

    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onAction(WishlistAction.Refresh)
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
            LargeTitle(L("Liste d'envies"))
            if (formats.size > 1) {
                FilterPills(formats.map { FilterPill(it.name, it.shelfLabel) }, selectedFormat?.name, { id -> send(WishlistAction.SelectFormat(id?.let { BookFormat.valueOf(it) })) })
            }
            if (wishlist.upcoming.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    RowHeader(L("Prochaines sorties"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                    ReleaseRail(wishlist.upcoming) { send(WishlistAction.OpenEdition(it)) }
                }
            }
            Rail(L("Disponibles"), editions(wishlist.released) { L("Sorti") })
            Rail(L("Conseillés par vos amis"), wishes(wishlist.fromFriends) { it.originCaption })
            Rail(L("Découvertes"), wishes(wishlist.discovered) { it.originCaption })
            Rail(L("Scannés"), wishes(wishlist.scanned) { DateText.dayMonthShort(DateText.local(it.wishedAt)) })
            Rail(L("Pas encore annoncés"), editions(wishlist.unannounced) { if (it.format == ReleaseFormat.AUDIOBOOK) L("Audio") else L("Traduction") })
        }
        if (wishlist.isEmpty) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                when {
                    isLoading -> CircularProgressIndicator()
                    errorMessage != null -> FailureState(L("Liste d'envies indisponible"), errorMessage) { onAction(WishlistAction.Refresh) }
                    else -> EmptyState("bookmark", L("Aucune envie"), L("Ajoutez-y un livre depuis Découvrir ou chez un ami, ou guettez sa traduction."))
                }
            }
        }
    }
}

@Composable
private fun ReleaseRail(editions: List<AwaitedEdition>, onOpen: (AwaitedEdition) -> Unit) {
    val state = rememberLazyListState()
    val inView by remember { derivedStateOf { state.firstVisibleItemIndex } }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        BoxWithConstraints {
            val width = maxWidth - 40.dp
            val cardWidth = if (editions.size > 1) width - 50.dp else width
            LazyRow(state = state, contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                items(editions, key = { it.id }) { edition ->
                    SeriesReleaseCard(
                        edition.volume,
                        edition.authors.firstOrNull() ?: "",
                        edition.format == ReleaseFormat.AUDIOBOOK,
                        onOpen = { onOpen(edition) },
                        modifier = Modifier.width(cardWidth),
                        place = edition.authors.firstOrNull() ?: "",
                    )
                }
            }
        }
        if (editions.size > 1) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                editions.indices.forEach { index ->
                    Box(Modifier.size(6.dp).background(if (index == inView) Shiori.colors.label else Shiori.colors.secondaryLabel.copy(alpha = 0.4f), CircleShape))
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun WishlistPagePreview() = PreviewSurface {
    WishlistPage(
        wishlist = com.polyforms.shiori.features.wishlist.Wishlist(awaited = DebugFixtures.discoverAwaited),
        formats = emptyList(),
        selectedFormat = null,
        isLoading = false,
        errorMessage = null,
    ) {}
}
