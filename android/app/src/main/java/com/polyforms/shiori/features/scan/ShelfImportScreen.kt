package com.polyforms.shiori.features.scan

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.platform.LoadingScreen

@Composable
fun ShelfImportScreen(onDismiss: () -> Unit) {
    Box(Modifier.fillMaxSize()) { LoadingScreen() }
}
