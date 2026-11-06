package com.polyforms.shiori.features.library

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun BookMosaicScreen(view: ShelvesView, formats: List<com.polyforms.shiori.shared.BookFormat>, client: LibraryClient) {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
