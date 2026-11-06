package com.polyforms.shiori.features.narrators

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun NarratorShelfScreen(library: com.polyforms.shiori.features.library.LibraryClient) {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
