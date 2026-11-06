package com.polyforms.shiori

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.zIndex
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.polyforms.shiori.features.friends.InvitationAcceptSheet
import com.polyforms.shiori.features.friends.InvitationRequest
import com.polyforms.shiori.features.friends.SharedScreen
import com.polyforms.shiori.features.home.HomeScreen
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.features.library.AddBookFlow
import com.polyforms.shiori.features.library.LibraryRequest
import com.polyforms.shiori.features.library.LibraryTab
import com.polyforms.shiori.features.series.SeriesRequest
import com.polyforms.shiori.features.news.NewsScreen
import com.polyforms.shiori.features.search.LibrarySearchScreen
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.PushRegistrar
import androidx.compose.runtime.LaunchedEffect
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.FloatingTabBar
import com.polyforms.shiori.shared.platform.NavigationStack
import com.polyforms.shiori.shared.platform.Navigator
import com.polyforms.shiori.shared.platform.TabItem
import java.time.Instant

enum class TabSelection {
    HOME, LIBRARY, NEWS, SEARCH, SCAN;

    val label: String
        get() = when (this) {
            HOME -> L("Accueil")
            LIBRARY -> L("Bibliothèque")
            NEWS -> L("Actu")
            SEARCH -> L("Rechercher")
            SCAN -> L("Scanner")
        }

    val symbol: String
        get() = when (this) {
            HOME -> "house"
            LIBRARY -> "book"
            NEWS -> "newspaper"
            SEARCH -> "magnifyingglass"
            SCAN -> "camera.viewfinder"
        }
}

/** Mutable routing the tabs share: what the dashboard asked the Library or Découvrir to show. */
class AppRouter {
    var selectedTab by mutableStateOf(TabSelection.HOME)
    var showAddSheet by mutableStateOf(false)
    var libraryRequest by mutableStateOf<LibraryRequest?>(null)
    var seriesRequest by mutableStateOf<SeriesRequest?>(null)
    var showShared by mutableStateOf(false)
    var invitation by mutableStateOf<InvitationRequest?>(null)
    var opensDiscover by mutableStateOf(false)

    /** Opens Découvrir, in the News tab. */
    fun showDiscover() {
        opensDiscover = true
        selectedTab = TabSelection.NEWS
    }

    /** Opens the Library on what the dashboard asked for. */
    fun openLibrary(request: LibraryRequest) {
        libraryRequest = request
        selectedTab = TabSelection.LIBRARY
    }

    /** Opens the Library's sagas, as the dashboard's series card asks. */
    fun openSeries(request: SeriesRequest) {
        seriesRequest = request
        selectedTab = TabSelection.LIBRARY
    }
}

/** The routing of the tabs, for the screens that send the reader to another tab. */
val LocalAppRouter = staticCompositionLocalOf { AppRouter() }

/**
 * The app once signed in: four tabs, each its own navigation stack kept alive, and the scan
 * button detached at the bar's end, which opens the add sheet rather than a tab.
 */
@Composable
fun ContentView(router: AppRouter = remember { AppRouter() }) {
    val navigators = remember { TabSelection.entries.associateWith { Navigator() } }
    val holder = rememberSaveableStateHolder()
    var backgroundedAt by remember { mutableStateOf<Instant?>(null) }

    // A return to the front after a while: every open screen reads again, as on iOS.
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) { if (backgroundedAt == null) backgroundedAt = Instant.now() }
    LifecycleEventEffect(Lifecycle.Event.ON_START) {
        if (backgroundedAt != null) DataChanges.post(null)
        backgroundedAt = null
    }

    CompositionLocalProvider(LocalAppRouter provides router) {
    val permission = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { granted ->
        PushRegistrar.pendingAnswer?.complete(granted)
    }
    LaunchedEffect(Unit) {
        PushRegistrar.requester = {
            if (android.os.Build.VERSION.SDK_INT < 33) {
                true
            } else {
                val answer = kotlinx.coroutines.CompletableDeferred<Boolean>()
                PushRegistrar.pendingAnswer = answer
                permission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                answer.await()
            }
        }
        PushRegistrar.refreshRegistration()
    }
    LaunchedEffect(Unit) { PushRegistrar.openDiscover.collect { router.showDiscover() } }
    LaunchedEffect(Unit) {
        MainActivity.invitations.collect {
            @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
            MainActivity.invitations.resetReplayCache()
            router.invitation = InvitationRequest(it)
        }
    }
    Box(Modifier.fillMaxSize()) {
        listOf(TabSelection.HOME, TabSelection.LIBRARY, TabSelection.NEWS, TabSelection.SEARCH).forEach { tab ->
            val visible = router.selectedTab == tab
            Box(Modifier.fillMaxSize().graphicsLayer { alpha = if (visible) 1f else 0f }.zIndex(if (visible) 1f else 0f)) {
                if (visible || navigators.getValue(tab).depth > 0 || tab == TabSelection.HOME) {
                    holder.SaveableStateProvider(tab) {
                        NavigationStack(navigators.getValue(tab), active = visible) {
                            when (tab) {
                                TabSelection.HOME -> HomeScreen()
                                TabSelection.LIBRARY -> LibraryTab()
                                TabSelection.NEWS -> NewsScreen()
                                TabSelection.SEARCH -> LibrarySearchScreen()
                                TabSelection.SCAN -> Unit
                            }
                        }
                    }
                }
            }
        }
        // The bar shows on a tab's root only, as iOS hides it under a pushed page.
        if (navigators.getValue(router.selectedTab).depth == 0) {
            Box(Modifier.align(Alignment.BottomCenter).zIndex(2f)) {
                FloatingTabBar(
                    tabs = listOf(TabSelection.HOME, TabSelection.LIBRARY, TabSelection.NEWS, TabSelection.SEARCH).map { TabItem(it, it.label, it.symbol) },
                    selected = router.selectedTab,
                    onSelect = { tab ->
                        if (tab == router.selectedTab) navigators.getValue(tab).popToRoot() else router.selectedTab = tab
                    },
                    trailing = TabItem(TabSelection.SCAN, TabSelection.SCAN.label, TabSelection.SCAN.symbol),
                    onTrailing = { router.showAddSheet = true },
                )
            }
        }
    }
        AddBookFlow(router)
        if (router.showShared) {
            ShioriSheet({ router.showShared = false }) {
                Box(Modifier.fillMaxSize()) { NavigationStack { SharedScreen() } }
            }
        }
        // The invitation is asked about rather than accepted: the link came from somewhere the
        // reader does not control, and accepting opens their library to whoever sent it.
        router.invitation?.let { InvitationAcceptSheet(it, { router.invitation = null }) }
    }
}
