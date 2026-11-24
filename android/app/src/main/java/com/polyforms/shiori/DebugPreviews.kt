package com.polyforms.shiori

import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.foundation.lazy.items

import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.molecules.ConfirmationHost

import androidx.compose.foundation.layout.fillMaxWidth

import androidx.compose.foundation.layout.padding

import androidx.compose.foundation.layout.statusBarsPadding

import com.polyforms.shiori.shared.BookFormat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.home.components.pages.HomeHeader
import com.polyforms.shiori.features.home.components.pages.HomePage
import com.polyforms.shiori.features.book.BookFixtures
import com.polyforms.shiori.features.book.components.pages.BookPage
import com.polyforms.shiori.features.listening.AudiblePlayers
import com.polyforms.shiori.features.listening.ListeningQueuePreviews
import com.polyforms.shiori.features.listening.ListeningTitlePreview
import com.polyforms.shiori.features.listening.Playback
import com.polyforms.shiori.features.listening.components.pages.PlayerPage
import com.polyforms.shiori.features.listening.components.pages.PlayerPageItem
import com.polyforms.shiori.features.listening.preview
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
            "review-saga" -> com.polyforms.shiori.features.scan.components.pages.ScanReviewPage(
                com.polyforms.shiori.features.scan.ScanFixtures.sagaDraft,
                null,
                isSaving = false,
                awaitable = listOf(com.polyforms.shiori.features.discover.ReleaseFormat.AUDIOBOOK),
                loadSubgenres = { emptyList() },
                loadVocabulary = { null },
                sagaVolumes = com.polyforms.shiori.features.scan.ScanFixtures.sagaVolumes,
                onClose = {},
            ) {}
            "review-confirmed" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                com.polyforms.shiori.features.scan.components.pages.ScanReviewPage(
                    DebugFixtures.reviewDraft,
                    null,
                    isSaving = false,
                    awaitable = listOf(com.polyforms.shiori.features.discover.ReleaseFormat.AUDIOBOOK),
                    loadSubgenres = { emptyList() },
                    loadVocabulary = { null },
                    onClose = {},
                ) {}
                com.polyforms.shiori.shared.components.molecules.ConfirmationHUD(
                    com.polyforms.shiori.shared.components.molecules.Confirmation.addedToLibrary.symbol,
                    com.polyforms.shiori.shared.components.molecules.Confirmation.addedToLibrary.label,
                    androidx.compose.ui.Modifier.align(androidx.compose.ui.Alignment.Center),
                )
            }
            "scan-analyzing" -> com.polyforms.shiori.features.scan.components.organisms.ScanAnalyzingPage()
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
            "awaited" -> com.polyforms.shiori.features.discover.AwaitedEditionScreen(DebugFixtures.discoverAwaited[0]) {}
            "news" -> com.polyforms.shiori.features.news.components.pages.NewsPage(
                com.polyforms.shiori.features.news.NewsFixtures.agenda(),
                isLoading = false,
                errorMessage = null,
                alertsSilenced = false,
            ) {}
            "upcoming" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.news.components.pages.UpcomingReleasesPage(com.polyforms.shiori.features.news.NewsFixtures.upcoming) {}
            }
            "tabbar" -> TabBarPreview()
            "components" -> com.polyforms.shiori.shared.components.styles.ShioriTheme(dark = true) { ComponentsPreview() }
            "kindle" -> com.polyforms.shiori.features.import.components.pages.ImportConnectPage(com.polyforms.shiori.features.import.ImportSource.KINDLE, com.polyforms.shiori.features.import.AmazonMarketplace.FR, {}, false) {}
            "kindle-library" -> com.polyforms.shiori.features.import.components.pages.ImportLibraryPage(
                com.polyforms.shiori.features.import.ImportSource.KINDLE, com.polyforms.shiori.features.import.ImportFixtures.kindleBooks,
                isLoading = false, isImporting = false, selectedCount = 1, canImport = true,
                isSelected = { it.asin == "B0G26NZ911" }, onToggle = {}, onSelectAll = {}, onDeselectAll = {}, onImport = {},
            )
            "audible-library" -> com.polyforms.shiori.features.import.components.pages.ImportLibraryPage(
                com.polyforms.shiori.features.import.ImportSource.AUDIBLE, com.polyforms.shiori.features.import.ImportFixtures.audibleBooks,
                isLoading = false, isImporting = false, selectedCount = 1, canImport = true,
                isSelected = { it.asin == "B002V1OF70" }, onToggle = {}, onSelectAll = {}, onDeselectAll = {}, onImport = {},
            )
            "audible-empty" -> com.polyforms.shiori.features.import.components.pages.ImportLibraryPage(
                com.polyforms.shiori.features.import.ImportSource.AUDIBLE, emptyList<com.polyforms.shiori.features.import.ImportableBook>(),
                isLoading = false, isImporting = false, selectedCount = 0, canImport = false,
                isSelected = { false }, onToggle = {}, onSelectAll = {}, onDeselectAll = {}, onImport = {},
            )
            "player" -> PlayerPage(PlayerPageItem.preview.copy(queue = ListeningQueuePreviews)) {}
            "player-queue" -> PlayerPage(PlayerPageItem.preview.copy(queue = ListeningQueuePreviews), queueProgress = 1f) {}
            "player-sleep" -> PlayerPage(PlayerPageItem.preview.copy(sleepMinutes = 20)) {}
            // The tabs with a title in the capsule over the bar, no stream behind it: a tap on
            // it opens the player's sheet.
            "player-accessory" -> {
                val context = androidx.compose.ui.platform.LocalContext.current
                remember { AudiblePlayers.app(context).apply { showPreview(ListeningTitlePreview, Playback.preview) } }
                ShioriRoot()
            }
            "pending-release" -> com.polyforms.shiori.features.news.components.pages.PendingReleasePage(
                com.polyforms.shiori.features.news.NewsFixtures.authorRelease,
                com.polyforms.shiori.features.news.components.pages.PendingReleasePhase.Loading,
            )
            "home-prompt", "home-done", "home-empty", "home-listening" -> androidx.compose.foundation.layout.Box(
                androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground),
            ) {
                val done = com.polyforms.shiori.features.discover.MonthlyDiscoveries(
                    com.polyforms.shiori.features.discover.MonthlyDiscoveries.month(java.time.Instant.now()),
                    suggestions = emptyList(),
                )
                HomePage(
                    if (name == "home-empty") com.polyforms.shiori.features.home.HomeFixtures.emptyDashboard else DebugFixtures.dashboard,
                    emptyList(),
                    emptySet(),
                    done,
                    isSearchingDiscoveries = false,
                    discoveryChoices = remember { DiscoveryChoices() },
                    onDiscoveryChoice = { _, _ -> true },
                    onRefresh = {},
                    header = { HomeHeader(false, avatar = {}) {} },
                    prompt = com.polyforms.shiori.features.home.HomePrompt.AUDIBLE.takeIf { name == "home-prompt" },
                    listeningState = { book -> com.polyforms.shiori.features.home.HomeFixtures.listenButton.takeIf { name == "home-listening" && book.format == com.polyforms.shiori.shared.BookFormat.AUDIOBOOK } },
                    isDownloaded = { name == "home-listening" && it.format == com.polyforms.shiori.shared.BookFormat.AUDIOBOOK },
                ) {}
            }
            else -> ShioriRoot()
        }
    }
}

/** The shared components the Android catch-up's foundation brought over, on one dark page. */
@Composable
private fun ComponentsPreview() {
    val black = androidx.compose.ui.graphics.Color.Black
    var on by remember { androidx.compose.runtime.mutableStateOf(false) }
    var hud by remember { androidx.compose.runtime.mutableStateOf<com.polyforms.shiori.shared.components.molecules.Confirmation?>(null) }
    val entries = listOf(com.polyforms.shiori.shared.platform.MenuEntry.Item(com.polyforms.shiori.shared.L("À lire"), "bookmark") {})
    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(black)) {
        androidx.compose.foundation.layout.Column(
            androidx.compose.ui.Modifier.fillMaxSize().statusBarsPadding().padding(20.dp),
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
        ) {
            androidx.compose.foundation.layout.Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                com.polyforms.shiori.shared.components.molecules.AddMenuButton(entries, size = com.polyforms.shiori.shared.components.molecules.AddMenuSize.PAGE)
                com.polyforms.shiori.shared.components.molecules.NotInterestedToggle(on, size = com.polyforms.shiori.shared.components.molecules.AddMenuSize.PAGE) { on = it }
                com.polyforms.shiori.shared.components.molecules.ActionToggle(true, "bell", "Suivre", "Ne plus suivre") {}
            }
            androidx.compose.foundation.layout.Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp)) {
                com.polyforms.shiori.shared.components.molecules.AddMenuButton(entries, size = com.polyforms.shiori.shared.components.molecules.AddMenuSize.PAGE, done = com.polyforms.shiori.shared.components.molecules.TakenState.Wished, onUndo = {})
                com.polyforms.shiori.shared.components.molecules.OwnedCapsule(size = com.polyforms.shiori.shared.components.molecules.AddMenuSize.PAGE)
            }
            androidx.compose.foundation.layout.Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                com.polyforms.shiori.shared.components.molecules.AddMenuButton(entries)
                com.polyforms.shiori.shared.components.molecules.AddMenuButton(entries, done = com.polyforms.shiori.shared.components.molecules.TakenState.Awaited(com.polyforms.shiori.features.discover.ReleaseFormat.BOOK), onUndo = {})
                com.polyforms.shiori.shared.components.atoms.StatusPill(com.polyforms.shiori.shared.components.atoms.HeroStatus.notInterested.text, "eye.slash")
            }
            androidx.compose.foundation.layout.Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)) {
                com.polyforms.shiori.shared.components.atoms.OutlinedTag("Audio")
                com.polyforms.shiori.shared.components.atoms.OutlinedTag(com.polyforms.shiori.shared.L("Guetté"), symbol = "binoculars.fill")
                com.polyforms.shiori.shared.components.atoms.OutlinedTag(com.polyforms.shiori.shared.L("Non partagé"), symbol = "eye.slash")
                com.polyforms.shiori.shared.components.atoms.DownloadedTag()
            }
            com.polyforms.shiori.shared.components.styles.ActionButton({ hud = com.polyforms.shiori.shared.components.molecules.Confirmation.addedToLibrary }, androidx.compose.ui.Modifier.fillMaxWidth(), size = com.polyforms.shiori.shared.components.styles.ActionSize.LARGE, spansWidth = true) {
                com.polyforms.shiori.shared.components.styles.ActionLabel("Continuer", null, 50.dp)
            }
            androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxWidth(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                com.polyforms.shiori.shared.components.organisms.SiriOrb(size = 220.dp)
            }
        }
        ConfirmationHost(hud) { hud = null }
    }
}

/** A long list under the real tab bar, folding as the list scrolls down. */
@Composable
private fun TabBarPreview() {
    val fold = remember { com.polyforms.shiori.shared.platform.TabBarFold() }
    val tabs = listOf(TabSelection.HOME, TabSelection.LIBRARY, TabSelection.NEWS, TabSelection.FRIENDS)
    var selected by remember { androidx.compose.runtime.mutableStateOf(TabSelection.LIBRARY) }
    val colors = com.polyforms.shiori.shared.components.styles.Shiori.colors
    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(colors.groupedBackground).nestedScroll(fold.connection)) {
        androidx.compose.foundation.lazy.LazyColumn(androidx.compose.ui.Modifier.fillMaxSize().statusBarsPadding()) {
            items(DebugFixtures.reading.size * 6) { index ->
                val book = DebugFixtures.reading[index % DebugFixtures.reading.size]
                com.polyforms.shiori.shared.components.organisms.BookRow(book)
            }
        }
        androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.align(androidx.compose.ui.Alignment.BottomCenter)) {
            com.polyforms.shiori.shared.platform.FloatingTabBar(
                tabs = tabs.map { com.polyforms.shiori.shared.platform.TabItem(it, it.label, it.symbol) },
                selected = selected,
                onSelect = { selected = it },
                trailing = com.polyforms.shiori.shared.platform.TabItem(TabSelection.SCAN, TabSelection.SCAN.label, TabSelection.SCAN.symbol),
                minimized = fold.isMinimized,
                onExpand = { fold.isMinimized = false },
            )
        }
    }
}
