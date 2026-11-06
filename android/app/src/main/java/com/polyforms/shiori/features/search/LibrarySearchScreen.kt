package com.polyforms.shiori.features.search

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.search.components.pages.LibrarySearchPage
import com.polyforms.shiori.features.search.components.pages.SearchAction
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.currentNavigator

/** The Search tab, connected. */
@Composable
fun LibrarySearchScreen(index: LibrarySearchIndex = LibrarySearchIndex.shared, client: LibrarySearchClient = LibrarySearchClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { LibrarySearchViewModel(index, client, scope) }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.appear() }
    LaunchedEffect(navigator.depth) { if (navigator.depth == 0) viewModel.refreshViewed() }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        LibrarySearchPage(
            viewModel.query,
            viewModel::type,
            viewModel.filter,
            viewModel.results,
            viewModel.recentSearches,
            viewModel.recentlyViewed,
            viewModel.covers,
            viewModel.isPreparing,
            viewModel.failed,
            viewModel.isSearching,
        ) { action ->
            when (action) {
                is SearchAction.OpenBook -> {
                    viewModel.opened()
                    navigator.push { BookScreen(action.book.id) }
                }
                is SearchAction.OpenSeries -> {
                    viewModel.opened()
                    navigator.push { SeriesScreen(action.hit.id) }
                }
                SearchAction.ToggleFavorites -> viewModel.toggleFavorites()
                is SearchAction.Select -> viewModel.select(action.status)
                SearchAction.ClearFilter -> viewModel.clearFilter()
                is SearchAction.UseRecent -> viewModel.useRecent(action.recent)
                SearchAction.ClearRecentSearches -> viewModel.clearRecentSearches()
                SearchAction.Retry -> viewModel.retry()
            }
        }
    }
}
