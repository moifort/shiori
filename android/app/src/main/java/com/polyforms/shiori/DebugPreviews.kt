package com.polyforms.shiori

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.home.components.pages.HomeHeader
import com.polyforms.shiori.features.home.components.pages.HomePage
import com.polyforms.shiori.features.book.BookFixtures
import com.polyforms.shiori.features.book.components.pages.BookPage
import com.polyforms.shiori.shared.platform.NavigationStack

/**
 * Pages drawn from their fixtures, opened by `adb shell am start … --es preview <name>` on a
 * debug build: how a screen is captured without a server, as the iOS previews are.
 */
@Composable
fun DebugPreviews(name: String) {
    NavigationStack {
        when (name) {
            "book" -> BookPage(
                BookFixtures.previewPaper,
                isSaving = false,
                onSetStatus = {},
                onRate = {},
                onOpenSeries = {},
                onEdit = {},
                onEditGenre = {},
                onEditRecommendation = {},
                onEditNote = {},
                onEditField = {},
            )
            "home" -> androidx.compose.foundation.layout.Box(
                androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground),
            ) {
                HomePage(
                    DebugFixtures.dashboard,
                    emptyList(),
                    emptySet(),
                    DebugFixtures.discoveries,
                    isSearchingDiscoveries = false,
                    discoveryChoices = remember { DiscoveryChoices() },
                    onDiscoveryChoice = { _, _ -> true },
                    onRefresh = {},
                    header = { HomeHeader(false, avatar = {}) {} },
                ) {}
            }
            "statistics" -> com.polyforms.shiori.features.home.HomeStatisticsScreen(DebugFixtures.dashboard, {}) { DebugFixtures.genreInsights }
            "genres" -> com.polyforms.shiori.features.home.GenreInsightsScreen { DebugFixtures.genreInsights }
            else -> ShioriRoot()
        }
    }
}
