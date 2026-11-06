package com.polyforms.shiori

import com.polyforms.shiori.shared.BookFormat

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
            "add" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.library.components.organisms.AddBookSheet(false, { emptyList() }, {}) {}
            }
            "review" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.scan.components.pages.ScanReviewPage(
                    DebugFixtures.reviewDraft,
                    null,
                    isSaving = false,
                    awaitable = emptyList(),
                    loadSubgenres = { emptyList() },
                    loadVocabulary = { null },
                ) {}
            }
            "scan" -> com.polyforms.shiori.features.scan.ScanScreen(onDismiss = {}, onAwait = { _, _ -> }, onAdded = {})
            "onboarding" -> androidx.compose.runtime.CompositionLocalProvider(com.polyforms.shiori.features.auth.LocalAuthSession provides remember { com.polyforms.shiori.features.auth.AuthSession() }) {
                com.polyforms.shiori.shared.components.styles.ShioriTheme(dark = true) {
                    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                        com.polyforms.shiori.shared.shell.CoverWall()
                        com.polyforms.shiori.features.onboarding.OnboardingScreen({ _, _ -> })
                    }
                }
            }
            "preparation" -> com.polyforms.shiori.shared.components.styles.ShioriTheme(dark = true) {
                androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                    com.polyforms.shiori.shared.shell.CoverWall()
                    com.polyforms.shiori.shared.shell.CoverVeil(covering = true)
                    androidx.compose.runtime.LaunchedEffect(Unit) { com.polyforms.shiori.features.home.LibraryPreparation.begin(listOf(com.polyforms.shiori.features.import.ImportSource.AUDIBLE)) }
                    if (com.polyforms.shiori.features.home.LibraryPreparation.isActive) com.polyforms.shiori.features.home.LibraryPreparationView()
                }
            }
            "audible" -> com.polyforms.shiori.features.import.components.pages.ImportConnectPage(com.polyforms.shiori.features.import.ImportSource.AUDIBLE, com.polyforms.shiori.features.import.AmazonMarketplace.FR, {}, false) {}
            "settings" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.settings.components.pages.SettingsHomePage("Thibaut Mottet", false, false, "1.0", "1") {}
            }
            "shared" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.friends.components.pages.SharedPage(DebugFixtures.myShelf, DebugFixtures.friends, false, null, false) {}
            }
            "friend" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.friends.components.pages.FriendProfilePage(DebugFixtures.friends[0], DebugFixtures.myShelf.copy(firstName = "Léa"), false, false, null) {}
            }
            "friend-book" -> com.polyforms.shiori.features.friends.components.pages.FriendBookPage(
                DebugFixtures.friendBook, "Léa", null, emptyList(), listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK), emptyList(),
            ) {}
            "discover" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                val feed = DebugFixtures.discoverFeed
                com.polyforms.shiori.features.discover.components.pages.DiscoverPage(
                    com.polyforms.shiori.shared.components.molecules.LibraryShelf.BOOKS,
                    feed,
                    DebugFixtures.discoverAwaited,
                    null,
                    emptyList(),
                    com.polyforms.shiori.features.discover.DiscoveriesLine.Shown(DebugFixtures.discoveries),
                    false,
                    false,
                    null,
                ) {}
            }
            "news" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                val feed = com.polyforms.shiori.features.news.NewsFeedLayout.feedSections(emptyList(), DebugFixtures.newsEvents, null, null)
                com.polyforms.shiori.features.news.components.pages.NewsPage(
                    feed, emptySet(), emptySet(), emptySet(),
                    com.polyforms.shiori.features.news.ReleaseCalendar(DebugFixtures.upcoming),
                    null,
                    com.polyforms.shiori.features.news.NewsFeedLayout.pillFormats(feed, null),
                    com.polyforms.shiori.features.news.NewsFeedLayout.stories(DebugFixtures.newsEvents, null),
                    null, false, false, false, null,
                ) {}
            }
            else -> ShioriRoot()
        }
    }
}
