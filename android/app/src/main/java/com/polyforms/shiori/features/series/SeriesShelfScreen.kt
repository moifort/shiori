package com.polyforms.shiori.features.series

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.series.components.pages.SeriesShelfAction
import com.polyforms.shiori.features.series.components.pages.SeriesShelfPage
import com.polyforms.shiori.features.series.components.pages.SetAsideSeriesPage
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** The Library's sagas, connected. */
@Composable
fun SeriesShelfScreen(filter: SeriesShelfFilter = SeriesShelfFilter.ALL, client: SeriesClient = SeriesClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { SeriesShelfViewModel(client, scope, filter) }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        SeriesShelfPage(
            viewModel.upNext,
            viewModel.releases,
            viewModel.filters,
            viewModel.filter,
            viewModel.filtered,
            viewModel.isLoading,
            viewModel.errorMessage,
        ) { action ->
            when (action) {
                is SeriesShelfAction.OpenSeries -> navigator.push { SeriesScreen(action.series.seriesId) }
                is SeriesShelfAction.SelectFilter -> viewModel.filter = action.filter
                is SeriesShelfAction.Follow -> viewModel.follow(action.series)
                SeriesShelfAction.Refresh -> viewModel.load()
            }
        }
        ScreenBar()
    }
}

/** The sagas set aside, connected. */
@Composable
fun SetAsideSeriesScreen(client: SeriesClient = SeriesClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { SeriesShelfViewModel(client, scope) }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        SetAsideSeriesPage(
            viewModel.setAside,
            viewModel.isLoading,
            onOpen = { navigator.push { SeriesScreen(it.seriesId) } },
            onFollow = { scope.launch { viewModel.follow(it) } },
        )
        ScreenBar()
    }
}
