package com.polyforms.shiori.features.discover

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun AnnouncedVolumeScreen(saga: SagaDiscovery, volume: DiscoveredVolume, linksToSaga: Boolean = true) {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
