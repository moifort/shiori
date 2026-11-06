package com.polyforms.shiori

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.polyforms.shiori.features.home.HomeScreen
import com.polyforms.shiori.features.library.LibraryTab
import com.polyforms.shiori.features.news.NewsScreen
import com.polyforms.shiori.features.search.LibrarySearchScreen
import com.polyforms.shiori.shared.DataChanges
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
}

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

    Box(Modifier.fillMaxSize()) {
        listOf(TabSelection.HOME, TabSelection.LIBRARY, TabSelection.NEWS, TabSelection.SEARCH).forEach { tab ->
            val visible = router.selectedTab == tab
            Box(Modifier.fillMaxSize().graphicsLayer { alpha = if (visible) 1f else 0f }) {
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
            Box(Modifier.align(Alignment.BottomCenter)) {
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
}
