package com.polyforms.shiori.features.series.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
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
import com.polyforms.shiori.features.home.components.organisms.SeriesShowCard
import com.polyforms.shiori.features.series.NextVolume
import com.polyforms.shiori.features.series.SeriesShelfFilter
import com.polyforms.shiori.features.series.components.organisms.SeriesReleaseCard
import com.polyforms.shiori.features.series.components.organisms.SeriesUpNextRail
import com.polyforms.shiori.features.series.isSetAside
import com.polyforms.shiori.features.series.missingCount
import com.polyforms.shiori.features.series.progress
import com.polyforms.shiori.features.series.releaseTag
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.LargeTitle
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface SeriesShelfAction {
    data class OpenSeries(val series: FollowedSeries) : SeriesShelfAction
    data class SelectFilter(val filter: SeriesShelfFilter) : SeriesShelfAction
    data class Follow(val series: FollowedSeries) : SeriesShelfAction
    data object Refresh : SeriesShelfAction
}

/** The Library's sagas: up next, the coming releases, then every saga under a filter. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SeriesShelfPage(
    upNext: List<Pair<FollowedSeries, NextVolume>>,
    releases: List<Pair<FollowedSeries, DiscoveredVolume>>,
    filters: List<SeriesShelfFilter>,
    filter: SeriesShelfFilter,
    series: List<FollowedSeries>,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (SeriesShelfAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: SeriesShelfAction) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }
    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onAction(SeriesShelfAction.Refresh)
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
            LargeTitle(L("Séries"))
            if (upNext.isNotEmpty()) SeriesUpNextRail(upNext) { send(SeriesShelfAction.OpenSeries(it)) }
            if (releases.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    RowHeader(L("Prochaines sorties"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                    ReleaseRail(releases) { send(SeriesShelfAction.OpenSeries(it)) }
                }
            }
            if (series.isNotEmpty() || filter != SeriesShelfFilter.ALL) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    RowHeader(L("Toutes les séries"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                    if (filters.size > 1) {
                        FilterPills(filters.map { FilterPill(it.name, it.label) }, filter.name, { id ->
                            send(SeriesShelfAction.SelectFilter(id?.let { SeriesShelfFilter.valueOf(it) } ?: SeriesShelfFilter.ALL))
                        }, allLabel = null)
                    }
                    if (filter == SeriesShelfFilter.NOT_FOLLOWED) SetAsideExplanation()
                    SeriesGrid(series, { saga -> if (filter == SeriesShelfFilter.INCOMPLETE) missingTag(saga) else saga.releaseTag }, onOpen = { send(SeriesShelfAction.OpenSeries(it)) }) {
                        send(SeriesShelfAction.Follow(it))
                    }
                }
            }
        }
        if (series.isEmpty() && upNext.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                when {
                    isLoading -> CircularProgressIndicator()
                    errorMessage != null -> FailureState(L("Séries indisponibles"), errorMessage) { onAction(SeriesShelfAction.Refresh) }
                }
            }
        }
    }
}

private fun missingTag(saga: FollowedSeries): String {
    val missing = saga.missingCount
    return if (missing == 1) L("1 tome à ajouter") else L("%lld tomes à ajouter", missing)
}

@Composable
fun SetAsideExplanation() {
    Text(
        L("Ces séries ne sont plus suivies : elles n'apparaissent ni dans « À suivre », ni dans les sorties, ni sur l'accueil. Leurs tomes restent dans la bibliothèque."),
        style = Shiori.type.subheadline,
        color = Shiori.colors.secondaryLabel,
        modifier = Modifier.padding(horizontal = 20.dp),
    )
}

/** Saga cards two to a row; a long press on a set-aside one offers to follow it again. */
@Composable
fun SeriesGrid(series: List<FollowedSeries>, tag: (FollowedSeries) -> String?, onOpen: (FollowedSeries) -> Unit, onFollow: (FollowedSeries) -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(13.dp)) {
        series.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(13.dp)) {
                pair.forEach { saga ->
                    var menu by remember { mutableStateOf(false) }
                    Box(Modifier.weight(1f)) {
                        SeriesShowCard(
                            saga.progress,
                            Modifier.fillMaxWidth().height(128.dp),
                            tag = tag(saga),
                            isCompact = true,
                            isSetAside = saga.isSetAside,
                            onLongPress = if (saga.isSetAside) ({ menu = true }) else null,
                        ) { onOpen(saga) }
                        MenuEntries(listOf(MenuEntry.Item(L("Suivre à nouveau"), "bell") { onFollow(saga) }), menu) { menu = false }
                    }
                }
                if (pair.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ReleaseRail(releases: List<Pair<FollowedSeries, DiscoveredVolume>>, onOpen: (FollowedSeries) -> Unit) {
    val state = rememberLazyListState()
    val inView by remember { derivedStateOf { state.firstVisibleItemIndex } }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        BoxWithConstraints {
            val width = maxWidth - 40.dp
            val cardWidth = if (releases.size > 1) width - 50.dp else width
            LazyRow(state = state, contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                itemsIndexed(releases, key = { _, entry -> entry.first.id }) { _, (saga, volume) ->
                    SeriesReleaseCard(volume, saga.author ?: saga.name, saga.isAudio, onOpen = { onOpen(saga) }, modifier = Modifier.width(cardWidth), language = saga.language)
                }
            }
        }
        if (releases.size > 1) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                releases.indices.forEach { index ->
                    Box(
                        Modifier.size(6.dp).background(
                            if (index == inView) Shiori.colors.label else Shiori.colors.secondaryLabel.copy(alpha = 0.4f),
                            CircleShape,
                        ),
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SeriesShelfPagePreview() = PreviewSurface {
    SeriesShelfPage(
        upNext = listOf(DebugFixtures.followedSeries[0] to com.polyforms.shiori.features.series.NextVolume.Owned(DebugFixtures.reading[2])),
        releases = listOf(DebugFixtures.followedSeries[0] to DebugFixtures.announcedVolume),
        filters = com.polyforms.shiori.features.series.SeriesShelfFilter.entries,
        filter = com.polyforms.shiori.features.series.SeriesShelfFilter.ALL,
        series = DebugFixtures.followedSeries,
        isLoading = false,
        errorMessage = null,
    ) {}
}
