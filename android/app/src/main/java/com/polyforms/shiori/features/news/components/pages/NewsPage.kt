package com.polyforms.shiori.features.news.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.news.FeedEvent
import com.polyforms.shiori.features.news.FriendStory
import com.polyforms.shiori.features.news.NarratorNews
import com.polyforms.shiori.features.news.NewsFeedItem
import com.polyforms.shiori.features.news.NewsFeedLayout
import com.polyforms.shiori.features.news.NewsFeedSection
import com.polyforms.shiori.features.news.ReleaseCalendar
import com.polyforms.shiori.features.news.ReleasedItem
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.features.news.components.organisms.FeedEventRow
import com.polyforms.shiori.features.news.components.organisms.FriendStoriesRail
import com.polyforms.shiori.features.news.components.organisms.ReleaseList
import com.polyforms.shiori.features.news.components.organisms.ReleasedRow
import com.polyforms.shiori.features.news.components.organisms.UpcomingRail
import com.polyforms.shiori.features.news.pillLabel
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.LoadMoreRow
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface NewsAction {
    data class SelectFormat(val format: BookFormat?) : NewsAction
    data class SelectFriend(val friendId: String?) : NewsAction
    data class OpenFriendBook(val event: FeedEvent) : NewsAction
    data class AddFriendBook(val event: FeedEvent, val status: CopiedStatus, val format: BookFormat) : NewsAction
    data class WishFriendBook(val event: FeedEvent) : NewsAction
    data class AwaitFriendBook(val event: FeedEvent, val format: ReleaseFormat) : NewsAction
    data class AddReleased(val item: ReleasedItem, val status: CopiedStatus, val format: BookFormat) : NewsAction
    data class WishReleased(val item: ReleasedItem) : NewsAction
    data class AwaitReleased(val item: ReleasedItem, val format: ReleaseFormat) : NewsAction
    data class OpenAuthor(val release: UpcomingRelease) : NewsAction
    data class OpenRelease(val release: UpcomingRelease) : NewsAction
    data object OpenUpcoming : NewsAction
    data class OpenNarrator(val news: NarratorNews) : NewsAction
    data object Invite : NewsAction
    data object OpenAlerts : NewsAction
    data class Prefetch(val id: String) : NewsAction
    data object LoadMore : NewsAction
    data object Refresh : NewsAction
}

/** The News: what is coming, the friends' faces, then what came out and what friends did. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewsPage(
    feed: List<NewsFeedSection>,
    taken: Set<String>,
    wished: Set<String>,
    awaited: Set<String>,
    calendar: ReleaseCalendar,
    format: BookFormat?,
    pillFormats: List<BookFormat>,
    stories: List<FriendStory>,
    friendId: String?,
    hasMore: Boolean,
    pageFailed: Boolean,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (NewsAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: NewsAction) {
        scope.launch { onAction(action) }
    }
    val colors = Shiori.colors
    val isEmpty = feed.isEmpty() && calendar.releases.isEmpty() && stories.isEmpty()
    val noHistory = feed.isEmpty() && format == null && friendId == null && !hasMore
    var refreshing by remember { mutableStateOf(false) }
    when {
        errorMessage != null && isEmpty && !isLoading -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Actualités indisponibles"), errorMessage) { onAction(NewsAction.Refresh) }
        }
        isLoading && isEmpty -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        else -> PullToRefreshBox(refreshing, onRefresh = {
            refreshing = true
            scope.launch {
                onAction(NewsAction.Refresh)
                refreshing = false
            }
        }, Modifier.fillMaxSize()) {
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 120.dp)) {
                item(key = "title") { LargeTitle(L("Actualités")) }
                if (calendar.releases.isNotEmpty()) {
                    item(key = "upcoming") {
                        Box(Modifier.padding(top = 8.dp)) { UpcomingRail(calendar.dated, { act(NewsAction.OpenUpcoming) }) { act(NewsAction.OpenRelease(it)) } }
                    }
                }
                if (stories.isNotEmpty() || noHistory) {
                    item(key = "stories") {
                        Box(Modifier.padding(top = if (calendar.releases.isEmpty()) 4.dp else 18.dp)) {
                            FriendStoriesRail(stories, friendId, { act(NewsAction.SelectFriend(it)) }) { act(NewsAction.Invite) }
                        }
                    }
                }
                if (noHistory) {
                    item(key = "no-history") {
                        Box(Modifier.fillMaxWidth().padding(top = if (calendar.releases.isEmpty()) 72.dp else 32.dp), contentAlignment = Alignment.Center) {
                            EmptyState("newspaper.fill", L("Rien de neuf pour l'instant"), L("Ce fil se remplit tout seul à partir de votre bibliothèque."))
                        }
                    }
                } else {
                    item(key = "pills") {
                        Box(Modifier.padding(top = 14.dp)) {
                            FilterPills(pillFormats.map { FilterPill(it.name, it.pillLabel) }, format?.name, { id -> act(NewsAction.SelectFormat(id?.let { BookFormat.valueOf(it) })) })
                        }
                    }
                    if (feed.isEmpty()) {
                        item(key = "released-empty") {
                            Text(L("Rien n'est sorti ces 30 derniers jours."), style = Shiori.type.footnote, color = colors.secondaryLabel, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 8.dp))
                        }
                    }
                    feed.forEach { section ->
                        item(key = "section-${section.id}") {
                            Text(section.title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 4.dp))
                        }
                        items(section.items, key = { it.id }) { item ->
                            when (item) {
                                is NewsFeedItem.Released -> {
                                    val released = item.item
                                    val open: (() -> Unit)? = when (released) {
                                        is ReleasedItem.Release -> if (released.release.author == null) null else ({ act(NewsAction.OpenAuthor(released.release)) })
                                        is ReleasedItem.Narrator -> ({ act(NewsAction.OpenNarrator(released.news)) })
                                    }
                                    ReleasedRow(
                                        released,
                                        released.id in taken,
                                        released.id in wished,
                                        released.id in awaited,
                                        open,
                                        onAdd = { status, taken -> act(NewsAction.AddReleased(released, status, taken)) },
                                        onWish = { act(NewsAction.WishReleased(released)) },
                                        onAwait = { act(NewsAction.AwaitReleased(released, it)) },
                                    )
                                }
                                is NewsFeedItem.Friend -> {
                                    val move = item.move
                                    LaunchedEffect(move.id) { onAction(NewsAction.Prefetch((move.others.lastOrNull() ?: move.lead).id)) }
                                    FeedEventRow(
                                        move.lead,
                                        move.others,
                                        move.lead.bookId in wished,
                                        move.lead.bookId in awaited,
                                        onOpen = { act(NewsAction.OpenFriendBook(move.lead)) },
                                        onAdd = { status, taken -> act(NewsAction.AddFriendBook(move.lead, status, taken)) },
                                        onWish = { act(NewsAction.WishFriendBook(move.lead)) },
                                        onAwait = { act(NewsAction.AwaitFriendBook(move.lead, it)) },
                                    )
                                }
                            }
                        }
                    }
                    if (hasMore) item(key = "more") { LoadMoreRow(pageFailed, L("Chargement de plus d'actualités")) { onAction(NewsAction.LoadMore) } }
                }
            }
        }
    }
}

/** Every release to come, filtered by format, in the calendar. */
@Composable
fun UpcomingReleasesPage(releases: List<UpcomingRelease>, onOpen: (UpcomingRelease) -> Unit) {
    var format by remember { mutableStateOf<BookFormat?>(null) }
    val colors = Shiori.colors
    val sections = ReleaseCalendar(releases.filter { format == null || it.format == format }).sections
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp)) {
        LargeTitle(L("À venir"))
        Box(Modifier.padding(top = 4.dp)) {
            FilterPills(NewsFeedLayout.pillFormats.map { FilterPill(it.name, it.pillLabel) }, format?.name, { id -> format = id?.let { BookFormat.valueOf(it) } })
        }
        if (sections.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 72.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Symbol("calendar"), null, Modifier.size(28.dp), tint = colors.secondaryLabel)
                Text(L("Rien d'annoncé pour l'instant"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                Text(L("Les prochaines sorties de vos séries, de vos auteurs et de vos livres guettés s'afficheront ici."), style = Shiori.type.footnote, color = colors.secondaryLabel, textAlign = TextAlign.Center)
            }
        } else {
            Box(Modifier.padding(top = 8.dp)) { ReleaseList(sections, onOpen) }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun NewsPagePreview() = PreviewSurface {
    val feed = com.polyforms.shiori.features.news.NewsFeedLayout.feedSections(emptyList(), DebugFixtures.newsEvents, null, null)
    NewsPage(
        feed = feed,
        taken = emptySet(),
        wished = emptySet(),
        awaited = emptySet(),
        calendar = com.polyforms.shiori.features.news.ReleaseCalendar(DebugFixtures.upcoming),
        format = null,
        pillFormats = com.polyforms.shiori.features.news.NewsFeedLayout.pillFormats(feed, null),
        stories = com.polyforms.shiori.features.news.NewsFeedLayout.stories(DebugFixtures.newsEvents, null),
        friendId = null,
        hasMore = false,
        pageFailed = false,
        isLoading = false,
        errorMessage = null,
    ) {}
}
