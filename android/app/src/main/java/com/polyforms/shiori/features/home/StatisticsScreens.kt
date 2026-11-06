package com.polyforms.shiori.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.home.components.organisms.FormatsCard
import com.polyforms.shiori.features.home.components.organisms.GenreRadar
import com.polyforms.shiori.features.home.components.organisms.GenreRecordsCard
import com.polyforms.shiori.features.home.components.organisms.GenreSignatureCard
import com.polyforms.shiori.features.home.components.organisms.GenresWidget
import com.polyforms.shiori.features.home.components.organisms.LastFinishedCard
import com.polyforms.shiori.features.home.components.organisms.ReadingChartWidget
import com.polyforms.shiori.features.home.components.organisms.StatTilesRow
import com.polyforms.shiori.features.home.components.organisms.TasteMap
import com.polyforms.shiori.features.home.components.organisms.UnexploredGenresCard
import com.polyforms.shiori.features.library.LibraryFilter
import com.polyforms.shiori.features.library.LibraryRequest
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** The year's statistics: tiles, genres, the reading chart, the last book finished. */
@Composable
fun StatisticsPage(dashboard: Dashboard, onShowLibrary: (LibraryRequest) -> Unit, onOpenGenres: () -> Unit, onOpenBook: (Book) -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 64.dp, bottom = 24.dp).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        StatTilesRow(
            dashboard.readCount,
            dashboard.favoriteCount,
            dashboard.toReadCount,
            onRead = { onShowLibrary(LibraryRequest(filter = LibraryFilter.Status(ReadingStatus.READ))) },
            onFavorites = { onShowLibrary(LibraryRequest(filter = LibraryFilter.Favorites)) },
            onPile = { onShowLibrary(LibraryRequest(filter = LibraryFilter.Status(ReadingStatus.TO_READ))) },
        )
        GenresWidget(dashboard.genres, onOpenGenres)
        ReadingChartWidget(dashboard.currentYear, dashboard.booksPerYear, dashboard.pagesPerMonth, dashboard.hoursPerMonth, dashboard.hasAudiobooks, dashboard.hasPrintedBooks)
        LastFinishedCard(dashboard.lastFinished, onOpenBook)
    }
}

@Composable
fun HomeStatisticsScreen(dashboard: Dashboard?, onShowLibrary: (LibraryRequest) -> Unit, genreInsights: suspend () -> GenreInsights) {
    val navigator = currentNavigator
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        if (dashboard != null) {
            StatisticsPage(dashboard, onShowLibrary, { navigator.push { GenreInsightsScreen(genreInsights) } }) { book -> navigator.push { BookScreen(book.id) } }
        } else {
            CircularProgressIndicator(Modifier.align(Alignment.Center))
        }
        ScreenBar(title = L("Statistiques"))
    }
}

/** What the reader's genres say of them. */
@Composable
fun GenreInsightsPage(insights: GenreInsights) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 56.dp, bottom = 24.dp).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        GenreRadar(insights.shares)
        GenreSignatureCard(insights.readCount, insights.shares)
        if (insights.formats.isNotEmpty()) FormatsCard(insights.formats)
        val average = insights.averageRating
        if (insights.tastes.size >= 3 && average != null) TasteMap(insights.tastes, average, insights.gem)
        if (insights.longest != null || insights.fastest != null || insights.mostDropped != null) {
            GenreRecordsCard(insights.longest, insights.fastest, insights.mostDropped)
        }
        if (insights.unexplored.isNotEmpty()) UnexploredGenresCard(insights.unexplored)
    }
}

@Composable
fun GenreInsightsScreen(load: suspend () -> GenreInsights) {
    var insights by remember { mutableStateOf<GenreInsights?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    suspend fun reload() {
        error = null
        try {
            insights = load()
        } catch (failure: Exception) {
            error = reportError(failure)
        }
    }
    LaunchedEffect(Unit) { reload() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { reload() } }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val shown = insights
        val failure = error
        when {
            shown != null -> GenreInsightsPage(shown)
            failure != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { FailureState(L("Genres indisponibles"), failure) { reload() } }
            else -> CircularProgressIndicator(Modifier.align(Alignment.Center))
        }
        ScreenBar(title = L("Genres lus"))
    }
}
