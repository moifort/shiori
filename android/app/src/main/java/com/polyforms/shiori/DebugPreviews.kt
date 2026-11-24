package com.polyforms.shiori

import com.polyforms.shiori.shared.components.styles.backdropSource
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
import com.polyforms.shiori.shared.platform.ScrollAwayBar
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
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.features.discover.book
import com.polyforms.shiori.features.discover.describedForPreview
import com.polyforms.shiori.features.discover.release
import com.polyforms.shiori.features.wishlist.release as wishRelease

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
            "friends" -> FriendsPreview(emptyList())
            "friends-one" -> FriendsPreview(listOf("sophie"))
            "friends-none" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                com.polyforms.shiori.features.friends.components.pages.FriendsPage(
                    emptyList(), emptyList(), com.polyforms.shiori.features.friends.FriendsShelf(), null, DebugFixtures.myShelf,
                    hasNoFriend = true, isWaiting = false, loadFailed = null, isInviting = false,
                ) {}
                ScrollAwayBar(com.polyforms.shiori.shared.L("Amis"), com.polyforms.shiori.shared.platform.rememberScrollAwayState())
            }
            "friend-books" -> com.polyforms.shiori.features.friends.FriendLibraryScreen("sophie", "Sophie", com.polyforms.shiori.features.friends.FriendsFixtures.client)
            "friend-series" -> com.polyforms.shiori.features.friends.FriendSeriesListScreen("sophie", "Sophie", com.polyforms.shiori.features.friends.FriendsFixtures.client)
            "friends-welcome" -> FriendsPreview(emptyList(), welcomed = "camille")
            "pasted-invitation" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Color.Black)) {
                com.polyforms.shiori.shared.platform.ShioriSheet({}) { com.polyforms.shiori.features.friends.components.pages.PastedInvitationSheet {} }
            }
            "friend-book" -> com.polyforms.shiori.features.friends.components.pages.FriendBookPage(
                DebugFixtures.friendBook, "Léa", null, emptyList(), listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK), emptyList(),
                awaitFormats = listOf(com.polyforms.shiori.features.discover.ReleaseFormat.AUDIOBOOK),
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
                    when (name) {
                        "home-empty" -> com.polyforms.shiori.features.home.HomeFixtures.emptyDashboard
                        // The audiobook's card first, where its play button shows.
                        "home-listening" -> DebugFixtures.dashboard.copy(reading = DebugFixtures.reading.sortedBy { it.format != com.polyforms.shiori.shared.BookFormat.AUDIOBOOK })
                        else -> DebugFixtures.dashboard
                    },
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
            "announced" -> {
                val opened = com.polyforms.shiori.features.discover.DiscoveryVolume(DebugFixtures.sagas[0], DebugFixtures.announcedVolume)
                com.polyforms.shiori.features.discover.components.pages.AnnouncedVolumePage(
                    opened,
                    opened.book(opened.release.describedForPreview),
                    isDescribing = false,
                    added = false,
                    linksToSaga = true,
                ) {}
            }
            "awaited-page" -> {
                val edition = com.polyforms.shiori.features.discover.DiscoverFixtures.awaitedFromFriend
                com.polyforms.shiori.features.discover.components.pages.AwaitedEditionPage(edition, edition.cover, isDescribing = false) {}
            }
            "award" -> {
                val winner = com.polyforms.shiori.features.discover.DiscoverFixtures.awardWinner
                com.polyforms.shiori.features.discover.components.pages.AwardWinnerPage(
                    winner,
                    winner.release.copy(publisher = "Saga Press", pageCount = 448).book("award-preview"),
                    isDescribing = false,
                    choices = remember { DiscoveryChoices() },
                    onChoice = { _, _ -> true },
                    others = listOf(com.polyforms.shiori.features.discover.DiscoverFixtures.goncourtWinner),
                ) {}
            }
            "suggestion" -> {
                val suggestion = DebugFixtures.discoveries.suggestions[0]
                com.polyforms.shiori.features.discover.components.pages.SuggestionPage(
                    suggestion,
                    suggestion.cover,
                    isDescribing = false,
                    choices = remember { DiscoveryChoices() },
                    onChoice = { _, _ -> true },
                ) {}
            }
            "wish" -> {
                val wish = com.polyforms.shiori.features.wishlist.WishlistFixtures.wishes[0]
                com.polyforms.shiori.features.wishlist.components.pages.WishPage(
                    wish,
                    wish.wishRelease.book("wish-${wish.id}"),
                    "https://www.amazon.fr/s?k=Hyperion",
                    isDescribing = false,
                    onAdd = {},
                    onRemove = {},
                    onChooseCover = {},
                )
            }
            "wishlist" -> androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) {
                com.polyforms.shiori.features.wishlist.components.pages.WishlistPage(
                    com.polyforms.shiori.features.wishlist.WishlistFixtures.wishlist,
                    listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK),
                    null,
                    isLoading = false,
                    errorMessage = null,
                ) {}
            }
            // Lot 4: Library, Series, Authors.
            "library-books", "friend-books" -> DebugPreviewGround {
                val books = DebugFixtures.reading + DebugFixtures.toRead
                androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                    com.polyforms.shiori.features.library.components.pages.BookMosaicPage(
                        com.polyforms.shiori.shared.ListSection.byMonth(books) { it.shelvedAt },
                        listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK, BookFormat.MANGA), null, null,
                        isLoading = false, errorMessage = null, hasMore = false, loadMoreFailed = false,
                        ownedByReader = if (name == "friend-books") ({ it.id == "r1" }) else null,
                    ) {}
                    ScreenBar {
                        com.polyforms.shiori.features.library.components.pages.MosaicStatusMenu(null) {}
                    }
                }
            }
            "series-shelf", "friend-series" -> DebugPreviewGround {
                val friend = name == "friend-series"
                val series = DebugFixtures.followedSeries
                androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
                    com.polyforms.shiori.features.series.components.pages.SeriesShelfPage(
                        upNext = if (friend) emptyList() else listOf(series[0] to com.polyforms.shiori.features.series.NextVolume.Owned(DebugFixtures.toRead[0])),
                        releases = if (friend) emptyList() else listOf(series[0] to DebugFixtures.announcedVolume),
                        filters = if (friend) emptyList() else com.polyforms.shiori.features.series.SeriesShelfFilter.entries,
                        filter = com.polyforms.shiori.features.series.SeriesShelfFilter.ALL,
                        series = series,
                        isLoading = false,
                        errorMessage = null,
                        statuses = if (friend) com.polyforms.shiori.features.series.SeriesStatusFilter.entries else emptyList(),
                        formats = if (friend) listOf(BookFormat.BOOK, BookFormat.MANGA) else emptyList(),
                        title = if (friend) null else com.polyforms.shiori.shared.L("Séries"),
                    ) {}
                    ScreenBar(title = if (friend) com.polyforms.shiori.shared.L("Séries") else null) {
                        if (friend) com.polyforms.shiori.features.series.components.pages.SeriesStatusMenu(com.polyforms.shiori.features.series.SeriesStatusFilter.entries, com.polyforms.shiori.features.series.SeriesStatusFilter.ALL) {}
                    }
                }
            }
            "series", "series-set-aside" -> com.polyforms.shiori.features.series.components.pages.SeriesPage(
                series = DebugFixtures.seriesCatalogue,
                owned = listOf(DebugFixtures.reading[2]),
                opinion = com.polyforms.shiori.shared.SeriesOpinion("frieren", rating = 4.0),
                isLoading = false,
                errorMessage = null,
                language = com.polyforms.shiori.shared.BookLanguage.FR,
                friend = null,
                isFollowed = name == "series",
                addingTitle = null,
                releases = com.polyforms.shiori.features.discover.SagaReleases(true, DebugFixtures.announcedVolume),
                takenFormat = BookFormat.MANGA,
                announcedVolume = { null },
            ) {}
            "authors" -> DebugPreviewGround {
                com.polyforms.shiori.features.authors.components.pages.PersonShelfPage(
                    "Auteurs", "Auteurs indisponibles", "Aucun auteur préféré", "",
                    listOf(DebugFixtures.author),
                    com.polyforms.shiori.features.authors.AuthorListOrder.RECENT,
                    isLoading = false, errorMessage = null, hasMore = false, loadMoreFailed = false,
                    releases = DebugFixtures.upcoming.take(4),
                    allTitle = "Tous les auteurs",
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
    val backdrop = com.polyforms.shiori.shared.components.styles.rememberBackdrop()
    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(colors.groupedBackground).nestedScroll(fold.connection)) {
        androidx.compose.foundation.lazy.LazyColumn(
            androidx.compose.ui.Modifier.fillMaxSize().backdropSource(backdrop).background(colors.groupedBackground).statusBarsPadding(),
        ) {
            items(DebugFixtures.reading.size * 6) { index ->
                val book = DebugFixtures.reading[index % DebugFixtures.reading.size]
                com.polyforms.shiori.shared.components.organisms.BookRow(book)
            }
        }
        androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.align(androidx.compose.ui.Alignment.BottomCenter)) {
          androidx.compose.runtime.CompositionLocalProvider(com.polyforms.shiori.shared.components.styles.LocalBackdrop provides backdrop) {
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
}

/** A page on the grouped ground, as its screen draws it. */
@Composable
private fun DebugPreviewGround(content: @Composable () -> Unit) =
    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(com.polyforms.shiori.shared.components.styles.Shiori.colors.groupedBackground)) { content() }

/** The Amis tab drawn from its fixtures, nobody or some friends picked. */
@Composable
private fun FriendsPreview(selected: List<String>, welcomed: String? = null) {
    val friends = com.polyforms.shiori.features.friends.FriendsFixtures.friends
    androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize()) {
        com.polyforms.shiori.features.friends.components.pages.FriendsPage(
            friends, selected, com.polyforms.shiori.features.friends.FriendsFixtures.shelf.narrowed(selected),
            selected.singleOrNull()?.let { id -> friends.first { it.userId == id } }, null,
            hasNoFriend = false, isWaiting = false, loadFailed = null, isInviting = false, welcomed = welcomed,
        ) {}
        ScrollAwayBar(com.polyforms.shiori.shared.L("Amis"), com.polyforms.shiori.shared.platform.rememberScrollAwayState()) {
            com.polyforms.shiori.shared.components.atoms.ToolbarIconButton(com.polyforms.shiori.shared.L("Inviter"), "person.badge.plus") {}
        }
    }
}
