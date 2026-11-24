package com.polyforms.shiori.features.news

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.LocalAppRouter
import com.polyforms.shiori.LocalTabIsShown
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.discover.AwardWinnerScreen
import com.polyforms.shiori.features.discover.SuggestionScreen
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.friends.FriendBookScreen
import com.polyforms.shiori.features.library.LibraryDestinationScreen
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.news.components.pages.NewsAction
import com.polyforms.shiori.features.news.components.pages.NewsPage
import com.polyforms.shiori.features.settings.NotificationSettingsScreen
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.platform.FullScreenCover
import com.polyforms.shiori.shared.platform.NavigationStack
import com.polyforms.shiori.shared.platform.Navigator
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/**
 * Runs `action` each time the tab comes to the front, as iOS's `.task` on a tab kept alive. On its
 * own, so that showing and hiding the tab recomposes this and not the screen.
 */
@Composable
private fun OnEachVisit(action: suspend () -> Unit) {
    val isShown = LocalTabIsShown.current
    LaunchedEffect(isShown) { if (isShown) action() }
}

/**
 * The Actu tab, connected: owns the ViewModel, its loads, and what a tap opens. Draws `NewsPage`.
 *
 * What opens is what the app already has: a friend's book on its read-only page, an author's
 * page, a narrator's page, a release on the page its watch holds.
 */
@Composable
fun NewsScreen(client: NewsClient = NewsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { NewsViewModel(client, scope) }
    val navigator = currentNavigator
    val router = LocalAppRouter.current
    var showsAlerts by remember { mutableStateOf(false) }
    OnEachVisit { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    // Laid out again only when what it is made of changes, not on each recomposition of the screen.
    val agenda by remember { derivedStateOf { viewModel.agenda() } }
    NewsPage(agenda, viewModel.wished, viewModel.isLoading, viewModel.errorMessage, viewModel.alertsSilenced) { action ->
        when (action) {
            is NewsAction.Open -> navigator.open(action.card)
            is NewsAction.Wish -> viewModel.wish(action.card)
            is NewsAction.Unwish -> viewModel.unwish(action.card)
            is NewsAction.Dismiss -> viewModel.dismiss(action.card)
            is NewsAction.Reconsider -> viewModel.reconsider(action.card)
            is NewsAction.Undo -> viewModel.undo(action.card, action.isWished)
            is NewsAction.Add -> viewModel.add(action.card, action.status, action.format)
            is NewsAction.AwaitEdition -> viewModel.awaitEdition(action.card, action.format)
            is NewsAction.OpenLibrary -> navigator.push { LibraryDestinationScreen(action.destination) }
            is NewsAction.OpenPerson -> when (val target = action.target) {
                is NewsPersonTarget.Friend -> router.showFriend(target.friendId)
                is NewsPersonTarget.Author -> navigator.push { AuthorScreen(target.author.key, target.author.name) }
                is NewsPersonTarget.Narrator -> navigator.push { NarratorScreen(target.narrator.key, target.narrator.name) }
            }
            NewsAction.OpenAlerts -> showsAlerts = true
            NewsAction.Refresh -> viewModel.load()
        }
    }
    if (showsAlerts) {
        val close = {
            showsAlerts = false
            scope.launch { viewModel.loadAlerts() }
            Unit
        }
        FullScreenCover(close) {
            NavigationStack {
                Box(Modifier.fillMaxSize()) {
                    NotificationSettingsScreen()
                    Box(Modifier.statusBarsPadding().padding(16.dp)) { ToolbarIconButton(L("Fermer"), "xmark", onClick = close) }
                }
            }
        }
    }
}

/**
 * A card's book on the page the rest of the app opens it on: a friend's on its read-only page, a
 * release on the volume, edition, author or narrator it came from, a discovery or a prize on its
 * own. A release looks itself up behind its loader.
 */
private fun Navigator.open(card: NewsCard) = push {
    when (card) {
        is NewsCard.Friend -> card.move.lead.let { FriendBookScreen(it.friendId, it.bookId, it.friendName) }
        is NewsCard.Released -> when (val item = card.item) {
            is ReleasedItem.Release -> UpcomingReleaseScreen(item.release)
            is ReleasedItem.Narrator -> NarratorScreen(item.news.narratorKey, item.news.narrator)
        }
        is NewsCard.Upcoming -> UpcomingReleaseScreen(card.release)
        // As on iOS, the page answers through its own writes; the card catches up on the next load.
        is NewsCard.Discovery -> SuggestionScreen(card.suggestion)
        is NewsCard.Award -> AwardWinnerScreen(card.winner)
    }
}

