package com.polyforms.shiori.features.discover

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen

@Composable
fun DiscoverScreen(onClose: () -> Unit) {
    Box(Modifier.fillMaxSize()) { LoadingScreen() }
}
