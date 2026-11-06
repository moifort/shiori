package com.polyforms.shiori.features.series.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.LargeTitle

/** The sagas the reader stopped following, with a way back. */
@Composable
fun SetAsideSeriesPage(series: List<FollowedSeries>, isLoading: Boolean, onOpen: (FollowedSeries) -> Unit, onFollow: (FollowedSeries) -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            LargeTitle(L("Non suivies"))
            SetAsideExplanation()
            SeriesGrid(series, { null }, onOpen, onFollow)
        }
        if (series.isEmpty() && isLoading) CircularProgressIndicator(Modifier.align(Alignment.Center))
    }
}
