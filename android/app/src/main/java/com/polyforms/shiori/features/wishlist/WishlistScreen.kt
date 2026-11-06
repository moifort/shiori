package com.polyforms.shiori.features.wishlist

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar

@Composable
fun WishlistScreen() {
    Box(Modifier.fillMaxSize()) {
        LoadingScreen()
        ScreenBar()
    }
}
