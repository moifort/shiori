package com.polyforms.shiori.features.home.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.features.home.HomeRelease
import com.polyforms.shiori.features.home.components.organisms.FriendsInviteCard
import com.polyforms.shiori.features.home.components.organisms.HomeEmptyHero
import com.polyforms.shiori.features.home.components.organisms.HomeFiguresLine
import com.polyforms.shiori.features.home.components.organisms.HomeHeroCarousel
import com.polyforms.shiori.features.home.components.organisms.HomeHeroItem
import com.polyforms.shiori.features.home.components.organisms.HomeSearchingHero
import com.polyforms.shiori.features.home.components.organisms.ImportSourcesRow
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.home.components.organisms.ReadingFeatureCard
import com.polyforms.shiori.features.home.daysAgo
import com.polyforms.shiori.features.home.doneMonth
import com.polyforms.shiori.features.home.leadCoverURL
import com.polyforms.shiori.features.home.needsRatingsMonth
import com.polyforms.shiori.features.home.releaseTile
import com.polyforms.shiori.features.home.shownOnHome
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.features.library.LibraryFilter
import com.polyforms.shiori.features.library.LibraryRequest
import com.polyforms.shiori.features.series.SeriesRequest
import com.polyforms.shiori.features.series.components.organisms.SeriesCardRail
import com.polyforms.shiori.features.series.components.organisms.SeriesRailCard
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import kotlinx.coroutines.launch
import java.time.Instant
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface HomeAction {
    data class ShowLibrary(val request: LibraryRequest) : HomeAction
    data class ShowSeries(val request: SeriesRequest) : HomeAction
    data class OpenSeries(val id: String) : HomeAction
    data class OpenBook(val book: Book) : HomeAction
    data object ShowStatistics : HomeAction
    data class FinishBook(val book: Book) : HomeAction
    data class RecordProgress(val book: Book) : HomeAction
    data object Scan : HomeAction
    data class ConnectSource(val source: ImportSource) : HomeAction
    data object ShowShared : HomeAction
    data object ShowDiscover : HomeAction
    data class OpenRelease(val release: HomeRelease) : HomeAction
    data class OpenDiscovery(val suggestion: Suggestion) : HomeAction
    data class SeeRelease(val release: HomeRelease) : HomeAction
    data class UnseeRelease(val release: HomeRelease) : HomeAction
}

object HomeCaptions {
    fun opened(book: Book): String {
        val startedAt = book.startedAt ?: return book.authorLine
        val days = startedAt.daysAgo()
        return if (days == 0) L("commencé aujourd'hui") else L("depuis %lldj", days)
    }

    fun shelved(book: Book): String {
        val addedAt = book.addedAt ?: return book.authorLine
        val days = addedAt.daysAgo()
        return when {
            days < 1 -> L("Aujourd'hui")
            days == 1 -> L("Hier")
            days < 30 -> L("%lld jours", days)
            days < 60 -> L("1 mois")
            days < 365 -> L("%lld mois", days / 30)
            days < 730 -> L("1 an")
            else -> L("%lld ans", days / 365)
        }
    }
}

fun homeHeroItems(releases: List<HomeRelease>, seen: Set<String>, discoveries: MonthlyDiscoveries?): List<HomeHeroItem> =
    HomeHeroItem.items(releases, discoveries?.shownOnHome ?: emptyList(), discoveries?.doneMonth(), discoveries?.needsRatingsMonth, seen)

/** Whether the Home opens on its full-bleed hero rather than on its figures. */
fun opensOnHero(dashboard: Dashboard?, releases: List<HomeRelease>, seen: Set<String>, discoveries: MonthlyDiscoveries?, isSearching: Boolean): Boolean {
    dashboard ?: return false
    if (dashboard.libraryIsEmpty) return true
    return homeHeroItems(releases, seen, discoveries).isNotEmpty() || isSearching
}

/** The Home on a phone: the hero, the figures, then the reading, the pile, the releases, the sagas. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomePage(
    dashboard: Dashboard,
    releases: List<HomeRelease>,
    seenReleases: Set<String>,
    discoveries: MonthlyDiscoveries?,
    isSearchingDiscoveries: Boolean,
    discoveryChoices: DiscoveryChoices,
    onDiscoveryChoice: suspend (Suggestion, DiscoveryChoice) -> Boolean,
    onRefresh: suspend () -> Unit,
    header: @Composable (onHero: Boolean) -> Unit,
    onAction: (HomeAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val items = homeHeroItems(releases, seenReleases, discoveries)
    val onHero = opensOnHero(dashboard, releases, seenReleases, discoveries, isSearchingDiscoveries)
    val month = discoveries?.month ?: MonthlyDiscoveries.month(Instant.now())
    var refreshing by remember { mutableStateOf(false) }

    @Composable
    fun Figures(modifier: Modifier) {
        HomeFiguresLine(
            dashboard.currentYear,
            dashboard.readThisYear,
            dashboard.favoriteCount,
            dashboard.toReadCount,
            dashboard.pagesThisYear,
            dashboard.hoursThisYear,
            showsPagesAtZero = dashboard.libraryIsEmpty,
            modifier = modifier,
        ) { onAction(HomeAction.ShowStatistics) }
    }

    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onRefresh()
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
            if (onHero) {
                ShioriTheme(dark = true) {
                    Column(Modifier.zIndex(1f).statusBarsPadding()) {
                        header(true)
                        Figures(Modifier.alpha(if (dashboard.libraryIsEmpty) 0.45f else 1f).padding(start = 24.dp, end = 24.dp, top = 6.dp, bottom = 12.dp))
                    }
                }
                when {
                    items.isNotEmpty() -> HomeHeroCarousel(
                        items,
                        onOpenRelease = { onAction(HomeAction.OpenRelease(it)) },
                        onOpen = { onAction(HomeAction.OpenDiscovery(it)) },
                        onChoice = onDiscoveryChoice,
                        choices = discoveryChoices,
                        onSeeRelease = { onAction(HomeAction.SeeRelease(it)) },
                        onUnseeRelease = { onAction(HomeAction.UnseeRelease(it)) },
                        onShowDiscover = { onAction(HomeAction.ShowDiscover) },
                        onRate = { onAction(HomeAction.ShowLibrary(LibraryRequest(filter = LibraryFilter.Status(ReadingStatus.READ)))) },
                        backdropCover = dashboard.leadCoverURL,
                        discoveryMonth = month,
                    )
                    dashboard.libraryIsEmpty -> HomeEmptyHero { onAction(HomeAction.Scan) }
                    else -> HomeSearchingHero(month, dashboard.readCount + dashboard.reading.size + dashboard.toReadCount, dashboard.leadCoverURL)
                }
            } else {
                Box(Modifier.statusBarsPadding()) { header(false) }
            }
            Column(Modifier.padding(top = if (onHero) 16.dp else 14.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
                if (dashboard.libraryIsEmpty) {
                    Section(L("Importer vos livres")) { Box(Modifier.padding(horizontal = 20.dp)) { ImportSourcesRow { onAction(HomeAction.ConnectSource(it)) } } }
                    Section(L("Partager"), onTitle = { onAction(HomeAction.ShowShared) }) {
                        Box(Modifier.padding(horizontal = 20.dp)) {
                            FriendsInviteCard(onInvite = { onAction(HomeAction.ShowShared) }, onEnterInvitation = { onAction(HomeAction.ShowShared) })
                        }
                    }
                } else if (!onHero) {
                    Figures(Modifier.padding(horizontal = 20.dp))
                }
                ReadingRow(dashboard, onAction)
                if (dashboard.toRead.isNotEmpty()) {
                    Section(L("Pile à lire"), onTitle = { onAction(HomeAction.ShowLibrary(LibraryRequest(filter = LibraryFilter.Status(ReadingStatus.TO_READ)))) }) {
                        PosterRow(dashboard.toRead.map { PosterRowItem(it, HomeCaptions.shelved(it)) }) { onAction(HomeAction.OpenBook(it)) }
                    }
                }
                if (releases.isNotEmpty() && !dashboard.libraryIsEmpty) {
                    Section(L("Prochaines sorties"), onTitle = { onAction(HomeAction.ShowDiscover) }) {
                        PosterRow(
                            releases.map { release ->
                                val upcoming = release.date?.let { ReleaseDateText.isUpcoming(it) } ?: false
                                PosterRowItem(
                                    releaseTile(release),
                                    if (upcoming) release.date?.let(ReleaseDateText::short) ?: "" else L("Disponible"),
                                ) { onAction(HomeAction.OpenRelease(release)) }
                            },
                        ) {}
                    }
                }
                if (dashboard.series.isNotEmpty()) {
                    Section(L("Séries en cours"), onTitle = { onAction(HomeAction.ShowSeries(SeriesRequest(state = SeriesState.IN_PROGRESS))) }) {
                        SeriesCardRail(dashboard.series.map { series -> SeriesRailCard(series, releaseTag(series.id, releases)) { onAction(HomeAction.OpenSeries(series.id)) } })
                    }
                }
            }
        }
    }
}

@Composable
private fun Section(title: String, onTitle: (() -> Unit)? = null, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE, action = onTitle)
        content()
    }
}

@Composable
private fun ReadingRow(dashboard: Dashboard, onAction: (HomeAction) -> Unit) {
    if (dashboard.reading.isEmpty()) return
    Section(L("En cours"), onTitle = { onAction(HomeAction.ShowLibrary(LibraryRequest(filter = LibraryFilter.Status(ReadingStatus.READING)))) }) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val width = maxWidth - 40.dp
            val cardWidth = if (dashboard.reading.size > 1) width - 32.dp else width
            LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                items(dashboard.reading, key = { it.id }) { book ->
                    ReadingFeatureCard(
                        book,
                        HomeCaptions.opened(book),
                        Modifier.width(cardWidth),
                        onOpen = { onAction(HomeAction.OpenBook(book)) },
                        onFinish = { onAction(HomeAction.FinishBook(book)) },
                        onProgress = { onAction(HomeAction.RecordProgress(book)) },
                        onOpenSeries = book.series?.let { series -> { onAction(HomeAction.OpenSeries(series.id)) } },
                    )
                }
            }
        }
    }
}

private fun releaseTag(seriesId: String, releases: List<HomeRelease>): String? {
    for (release in releases) {
        if (release !is HomeRelease.Volume || release.release.saga.series.seriesId != seriesId) continue
        val volume = release.release.volume
        val date = volume.date
        if (date == null || !ReleaseDateText.isUpcoming(date)) return L("Tome %lld disponible", volume.number)
        return L("Tome %lld · %@", volume.number, ReleaseDateText.short(date))
    }
    return null
}

/** The Home's bar: its title, then the admin's shield and the account's face. */
@Composable
fun HomeHeader(isAdmin: Boolean, avatar: @Composable () -> Unit, onAdmin: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(L("Accueil"), style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Shiori.colors.label)
        Spacer(Modifier.weight(1f))
        if (isAdmin) {
            com.polyforms.shiori.shared.components.atoms.ToolbarIconButton(L("Admin"), "shield", onClick = onAdmin)
            Spacer(Modifier.width(8.dp))
        }
        avatar()
    }
}

@Preview(showBackground = true)
@Composable
private fun HomePagePreview() = PreviewSurface {
    HomePage(
        DebugFixtures.dashboard,
        releases = emptyList(),
        seenReleases = emptySet(),
        discoveries = DebugFixtures.discoveries,
        isSearchingDiscoveries = false,
        discoveryChoices = androidx.compose.runtime.remember { com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices() },
        onDiscoveryChoice = { _, _ -> true },
        onRefresh = {},
        header = { HomeHeader(isAdmin = false, avatar = {}) {} },
    ) {}
}
