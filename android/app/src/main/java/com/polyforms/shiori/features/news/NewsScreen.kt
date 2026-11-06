package com.polyforms.shiori.features.news

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.LocalAppRouter
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.discover.AnnouncedVolumeScreen
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.discover.DiscoverApi
import com.polyforms.shiori.features.discover.DiscoverScreen
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.FriendBookScreen
import com.polyforms.shiori.features.friends.InvitationSheet
import com.polyforms.shiori.features.narrators.NarratorDestination
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.news.components.pages.NewsAction
import com.polyforms.shiori.features.news.components.pages.NewsPage
import com.polyforms.shiori.features.news.components.pages.UpcomingReleasesPage
import com.polyforms.shiori.features.settings.NotificationSettingsScreen
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.FullScreenCover
import com.polyforms.shiori.shared.platform.NavigationStack
import com.polyforms.shiori.shared.platform.Navigator
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** Where a release to come leads: its volume announced, the edition awaited, the author, the narrator. */
sealed interface UpcomingReleaseDestination {
    data class Announced(val volume: DiscoveryVolume) : UpcomingReleaseDestination
    data class Awaited(val edition: AwaitedEdition) : UpcomingReleaseDestination
    data class Author(val author: AuthorDestination) : UpcomingReleaseDestination
    data class Narrator(val narrator: NarratorDestination) : UpcomingReleaseDestination

    companion object {
        suspend fun of(release: UpcomingRelease): UpcomingReleaseDestination? {
            val format = if (release.format == BookFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK
            return when (release.source) {
                ReleaseSource.SAGA -> {
                    val page = runCatching { DiscoverApi.discovery(format) }.getOrNull() ?: return null
                    val row = page.rows.firstOrNull {
                        it.series.name == release.seriesName && it.releases.next?.number == release.volume && (release.language == null || it.series.language == release.language)
                    } ?: return null
                    val next = row.releases.next ?: return null
                    Announced(DiscoveryVolume(row, next))
                }
                ReleaseSource.AWAITED -> {
                    val id = release.id.removePrefix("awaited~")
                    val edition = runCatching { AwaitedApi.awaited(format) }.getOrNull()?.firstOrNull { it.id == id } ?: return null
                    Awaited(edition)
                }
                ReleaseSource.AUTHOR -> release.author?.let { Author(AuthorDestination(it.key, it.name)) }
                ReleaseSource.NARRATOR -> {
                    val parts = release.id.split("~")
                    val name = release.narrator ?: return null
                    if (parts.size < 2) null else Narrator(NarratorDestination(parts[1], name))
                }
            }
        }
    }
}

private fun Navigator.open(destination: UpcomingReleaseDestination) = push {
    when (destination) {
        is UpcomingReleaseDestination.Announced -> AnnouncedVolumeScreen(destination.volume.saga, destination.volume.volume)
        is UpcomingReleaseDestination.Awaited -> AwaitedEditionScreen(destination.edition) {}
        is UpcomingReleaseDestination.Author -> AuthorScreen(destination.author.key, destination.author.name)
        is UpcomingReleaseDestination.Narrator -> NarratorScreen(destination.narrator.key, destination.narrator.name)
    }
}

/** The News tab, connected; Découvrir opens over it. */
@Composable
fun NewsScreen(client: NewsClient = NewsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { NewsViewModel(client, scope) }
    val navigator = currentNavigator
    val router = LocalAppRouter.current
    var showsAlerts by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        NewsPage(
            viewModel.feedSections(),
            viewModel.taken,
            viewModel.wished,
            viewModel.awaited,
            viewModel.calendar(),
            viewModel.format,
            viewModel.pillFormats(),
            viewModel.stories,
            viewModel.friendId,
            viewModel.hasMore,
            viewModel.pageFailed,
            viewModel.isLoading,
            viewModel.errorMessage,
        ) { action ->
            when (action) {
                is NewsAction.SelectFormat -> viewModel.format = action.format
                is NewsAction.SelectFriend -> viewModel.friendId = action.friendId
                is NewsAction.OpenFriendBook -> navigator.push { FriendBookScreen(action.event.friendId, action.event.bookId, action.event.friendName) }
                is NewsAction.AddFriendBook -> viewModel.add(action.event, action.status, action.format)
                is NewsAction.WishFriendBook -> viewModel.wish(action.event)
                is NewsAction.AwaitFriendBook -> viewModel.awaitEdition(action.event, action.format)
                is NewsAction.AddReleased -> viewModel.add(action.item, action.status, action.format)
                is NewsAction.WishReleased -> viewModel.wish(action.item)
                is NewsAction.AwaitReleased -> viewModel.awaitEdition(action.item, action.format)
                is NewsAction.OpenAuthor -> action.release.author?.let { author -> navigator.push { AuthorScreen(author.key, author.name) } }
                is NewsAction.OpenNarrator -> navigator.push { NarratorScreen(action.news.narratorKey, action.news.narrator) }
                is NewsAction.OpenRelease -> UpcomingReleaseDestination.of(action.release)?.let { navigator.open(it) }
                NewsAction.OpenUpcoming -> navigator.push {
                    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
                        UpcomingReleasesPage(viewModel.calendar().releases) { release -> scope.launch { UpcomingReleaseDestination.of(release)?.let { navigator.open(it) } } }
                        ScreenBar()
                    }
                }
                NewsAction.Invite -> viewModel.invite()
                NewsAction.OpenAlerts -> showsAlerts = true
                is NewsAction.Prefetch -> viewModel.prefetchIfNeeded(action.id)
                NewsAction.LoadMore -> viewModel.loadMore()
                NewsAction.Refresh -> viewModel.load()
            }
        }
        Box(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(16.dp)) {
            ToolbarIconButton(L("Notifications"), if (viewModel.alertsSilenced) "bell.slash" else "bell") { showsAlerts = true }
        }
    }
    if (showsAlerts) {
        FullScreenCover({
            showsAlerts = false
            scope.launch { viewModel.loadAlerts() }
        }) {
            NavigationStack {
                Box(Modifier.fillMaxSize()) {
                    NotificationSettingsScreen()
                    Box(Modifier.statusBarsPadding().padding(16.dp)) {
                        ToolbarIconButton(L("Fermer"), "xmark") {
                            showsAlerts = false
                            scope.launch { viewModel.loadAlerts() }
                        }
                    }
                }
            }
        }
    }
    viewModel.invitation?.let { InvitationSheet(it) { viewModel.invitation = null } }
    if (router.opensDiscover) {
        FullScreenCover({ router.opensDiscover = false }) {
            NavigationStack { DiscoverScreen { router.opensDiscover = false } }
        }
    }
}
