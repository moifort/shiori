package com.polyforms.shiori.features.home

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun HomeStatisticsScreen(dashboard: Dashboard?, onShowLibrary: (com.polyforms.shiori.features.library.LibraryRequest) -> Unit, genreInsights: suspend () -> GenreInsights) {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
