package com.polyforms.shiori.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.TabSelection
import com.polyforms.shiori.features.friends.FriendsClient
import com.polyforms.shiori.features.listening.ListeningButtonState
import com.polyforms.shiori.features.listening.LocalAudiblePlayer
import com.polyforms.shiori.features.listening.press
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.LocalAppRouter
import com.polyforms.shiori.features.admin.AdminScreen
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.book.components.pages.ReadingProgressSheet
import com.polyforms.shiori.features.discover.AnnouncedVolumeScreen
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.discover.SuggestionScreen
import com.polyforms.shiori.features.home.components.organisms.FinishedBookSheet
import com.polyforms.shiori.features.home.components.pages.HomeAction
import com.polyforms.shiori.features.home.components.pages.HomeHeader
import com.polyforms.shiori.features.home.components.pages.HomePage
import com.polyforms.shiori.features.import.AudibleImportScreen
import com.polyforms.shiori.features.import.BackgroundSync
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.import.KindleImportScreen
import com.polyforms.shiori.features.onboarding.LocalAccount
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.settings.SettingsHomeScreen
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

private sealed interface HomeSheet {
    data class Finished(val book: Book) : HomeSheet
    data class Progress(val book: Book) : HomeSheet
}

/** The Home tab, connected: the dashboard and every page it opens. */
@Composable
fun HomeScreen(
    client: HomeClient = HomeClient.live,
    friendsClient: FriendsClient = FriendsClient.live,
    /** Whether an Audible title is kept on the phone, for its card's tag. */
    isDownloaded: (Book) -> Boolean = { false },
) {
    /** The Audible player, in a build that carries it. */
    val player = LocalAudiblePlayer.current
    val scope = rememberCoroutineScope()
    val viewModel = remember { HomeViewModel(client, scope) }
    val navigator = currentNavigator
    val router = LocalAppRouter.current
    val account = LocalAccount.current
    var sheet by remember { mutableStateOf<HomeSheet?>(null) }

    LaunchedEffect(Unit) {
        if (LibraryPreparation.isActive) {
            LibraryPreparation.loadHome = {
                viewModel.load()
                viewModel.errorMessage == null
            }
        }
        viewModel.loadOnAppear()
    }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    // Left for another tab or a page pushed over it: the discoveries taken and the releases seen
    // from the carousel leave the line while out of sight.
    val inSight = router.selectedTab == TabSelection.HOME && navigator.depth == 0
    LaunchedEffect(inSight) { if (!inSight) viewModel.releaseTaken() }
    val context = LocalContext.current

    /** The hero's "Inviter": the link straight into the share sheet, as the Amis tab sends it. */
    fun invite() = scope.launch {
        try {
            val invitation = friendsClient.invite()
            com.polyforms.shiori.features.friends.InvitationShare.present(context, invitation)
        } catch (error: Exception) {
            if (!isCancellation(error)) viewModel.actionError = reportError(error)
        }
    }

    fun connect(source: ImportSource) = navigator.push {
        when (source) {
            ImportSource.AUDIBLE -> AudibleImportScreen { navigator.pop() }
            ImportSource.KINDLE -> KindleImportScreen { navigator.pop() }
        }
        // The import lands through the change notice, as every write does; a connection alone
        // does not, and takes its prompt off the hero once the page is left.
        DisposableEffect(Unit) { onDispose { scope.launch { viewModel.load() } } }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val dashboard = viewModel.dashboard
        val error = viewModel.errorMessage
        when {
            dashboard != null -> HomePage(
                dashboard,
                viewModel.releases,
                viewModel.hiddenReleases,
                viewModel.discoveries,
                viewModel.isSearchingDiscoveries,
                viewModel.discoveryChoices,
                viewModel::choose,
                prompt = viewModel.shownPrompt,
                listeningState = { ListeningButtonState.of(it, player) },
                isDownloaded = isDownloaded,
                onRefresh = viewModel::load,
                header = {
                    HomeHeader(account.isAdmin, avatar = {
                        AccountAvatarView(account.avatar, account.firstName, modifier = Modifier.plainClickable { navigator.push { SettingsHomeScreen() } })
                    }) { navigator.push { AdminScreen() } }
                },
            ) { action ->
                when (action) {
                    is HomeAction.ShowLibrary -> router.openLibrary(action.request)
                    is HomeAction.ShowSeries -> router.openSeries(action.request)
                    is HomeAction.OpenSeries -> navigator.push { SeriesScreen(action.id) }
                    is HomeAction.OpenBook -> navigator.push { BookScreen(action.book.id) }
                    HomeAction.ShowStatistics -> navigator.push {
                        HomeStatisticsScreen(viewModel.dashboard, { router.openLibrary(it) }, viewModel::genreInsights)
                    }
                    is HomeAction.FinishBook -> sheet = HomeSheet.Finished(action.book)
                    is HomeAction.RecordProgress -> sheet = HomeSheet.Progress(action.book)
                    HomeAction.Scan -> router.showAddSheet = true
                    is HomeAction.ConnectSource -> connect(action.source)
                    is HomeAction.Listen -> player?.press(action.state, action.book)
                    is HomeAction.OpenRelease -> when (val release = action.release) {
                        is HomeRelease.Volume -> navigator.push { AnnouncedVolumeScreen(release.release.saga, release.release.volume) }
                        is HomeRelease.Awaited -> navigator.push {
                            AwaitedEditionScreen(release.edition) { scope.launch { viewModel.stopAwaiting(release.edition) } }
                        }
                    }
                    is HomeAction.OpenDiscovery -> navigator.push {
                        SuggestionScreen(action.suggestion, viewModel.discoveryChoices, viewModel::choose)
                    }
                    is HomeAction.SeeRelease -> viewModel.see(action.release)
                    is HomeAction.UnseeRelease -> viewModel.unsee(action.release)
                    is HomeAction.OpenPrompt -> when (action.prompt) {
                        HomePrompt.AUDIBLE -> connect(ImportSource.AUDIBLE)
                        HomePrompt.KINDLE -> connect(ImportSource.KINDLE)
                        HomePrompt.FRIENDS -> invite()
                    }
                    is HomeAction.DismissPrompt -> viewModel.dismiss(action.prompt)
                    is HomeAction.UndismissPrompt -> viewModel.undismiss(action.prompt)
                }
            }
            error != null -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
                FailureState(L("Accueil indisponible"), error) { viewModel.load() }
            }
            else -> CircularProgressIndicator(Modifier.align(Alignment.Center))
        }
    }

    when (val shown = sheet) {
        is HomeSheet.Finished -> FinishedBookSheet(shown.book, onDone = { stars ->
            sheet = null
            scope.launch {
                viewModel.finish(shown.book)
                if (stars != null) viewModel.rate(shown.book, stars)
            }
        }, onCancel = { sheet = null })
        is HomeSheet.Progress -> ReadingProgressSheet(shown.book.currentPage, shown.book.pageCount, { sheet = null }) { page, status ->
            viewModel.recordPage(shown.book, page, status)
        }
        null -> Unit
    }
    val audible = BackgroundSync.audible
    val kindle = BackgroundSync.kindle
    val syncError = audible.errorMessage ?: kindle.errorMessage
    if (syncError != null) {
        ShioriAlert(
            if (audible.errorMessage != null) L("Import Audible interrompu") else L("Import Kindle interrompu"),
            L("%@ Vous pouvez relancer la synchronisation depuis les réglages.", syncError),
            onDismiss = { if (audible.errorMessage != null) audible.errorMessage = null else kindle.errorMessage = null },
        )
    }
    viewModel.actionError?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.actionError = null }) }
}

