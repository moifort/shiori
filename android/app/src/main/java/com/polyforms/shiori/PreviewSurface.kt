package com.polyforms.shiori

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import com.polyforms.shiori.shared.platform.NavigationStack

/**
 * What every component's `@Preview` draws in: the app's theme, a navigator for the parts
 * that push, and the grouped background, as the iOS previews sit on the system's. The
 * values come from [DebugFixtures], never from the server.
 */
@Composable
fun PreviewSurface(dark: Boolean = false, content: @Composable () -> Unit) {
    ShioriTheme(dark = dark) {
        NavigationStack {
            Box(Modifier.background(Shiori.colors.groupedBackground)) { content() }
        }
    }
}
