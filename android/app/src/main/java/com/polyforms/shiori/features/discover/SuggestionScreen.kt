package com.polyforms.shiori.features.discover

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun SuggestionScreen(suggestion: Suggestion, choices: com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices, onChoice: suspend (Suggestion, com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice) -> Boolean) {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
