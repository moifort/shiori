package com.polyforms.shiori.features.friends.components.pages

import com.polyforms.shiori.shared.platform.pageEndRoom

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.ui.unit.Dp
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
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
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.friends.Friend
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.FriendProfile
import com.polyforms.shiori.features.friends.FriendsFixtures
import com.polyforms.shiori.features.friends.FriendsShelf
import com.polyforms.shiori.features.friends.FriendsShelfEntry
import com.polyforms.shiori.features.friends.components.organisms.FriendAvatarItem
import com.polyforms.shiori.features.friends.components.organisms.FriendAvatarPicker
import com.polyforms.shiori.features.friends.components.organisms.FriendsEmptyInvite
import com.polyforms.shiori.features.friends.components.organisms.FriendsRail
import com.polyforms.shiori.features.friends.components.organisms.FriendsRailItem
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch

/** Everything the Amis tab can ask for. */
sealed interface FriendsAction {
    data class Toggle(val friendId: String) : FriendsAction
    data class OpenBook(val entry: FriendsShelfEntry) : FriendsAction
    data class OpenMyBook(val book: FriendBook) : FriendsAction
    data class OpenLibrary(val friend: Friend) : FriendsAction
    data class OpenSeries(val friend: Friend) : FriendsAction
    data object Invite : FriendsAction

    /** A friend's avatar held, "Retirer" chosen and confirmed. */
    data class Remove(val friendId: String) : FriendsAction
    data object Refresh : FriendsAction
}

/**
 * The Amis tab, as the Library tab lays itself out: the friends' avatars at the top, which narrow
 * the whole page — nobody picked shows every friend, each one tapped narrows it to the friends
 * picked — then, for one friend, the rows of their books and series, and the rails: what they are
 * reading, what they hearted, what they finished, what waits on their pile. A rail with nothing in
 * it is not drawn. With more than one friend shown, each cover says whose it is.
 *
 * Without a friend, the page invites one: the reader's avatar among empty places, and what their
 * friends will see of their shelf.
 *
 * [scroll] is the bar's: it goes away as the page scrolls down.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendsPage(
    friends: List<Friend>,
    selected: List<String>,
    shelf: FriendsShelf,
    soleFriend: Friend?,
    myShelf: FriendProfile?,
    hasNoFriend: Boolean,
    isWaiting: Boolean,
    loadFailed: String?,
    isInviting: Boolean,
    modifier: Modifier = Modifier,
    welcomed: String? = null,
    scroll: NestedScrollConnection? = null,
    onAction: suspend (FriendsAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: FriendsAction) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }
    Box(modifier.fillMaxSize().background(Shiori.colors.background)) {
        when {
            loadFailed != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                FailureState(L("Impossible de charger vos amis"), loadFailed) { onAction(FriendsAction.Refresh) }
            }
            else -> PullToRefreshBox(
                refreshing,
                onRefresh = {
                    refreshing = true
                    scope.launch {
                        onAction(FriendsAction.Refresh)
                        refreshing = false
                    }
                },
                Modifier.fillMaxSize(),
            ) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .then(if (scroll != null) Modifier.nestedScroll(scroll) else Modifier)
                        .verticalScroll(rememberScrollState()),
                ) {
                    // The bar's room: the page's colours run under it, its rows start below it.
                    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 56.dp
                    if (hasNoFriend) {
                        FriendsEmptyInvite(myShelf, isInviting, onInvite = { onAction(FriendsAction.Invite) }, onOpenMyBook = { send(FriendsAction.OpenMyBook(it)) }, top = top)
                    } else {
                        Content(friends, selected, shelf, soleFriend, welcomed, top, ::send)
                    }
                }
            }
        }
        if (isWaiting) CircularProgressIndicator(Modifier.align(Alignment.TopCenter).padding(top = 120.dp))
    }
}

@Composable
private fun Content(friends: List<Friend>, selected: List<String>, shelf: FriendsShelf, soleFriend: Friend?, welcomed: String?, top: Dp, send: (FriendsAction) -> Unit) {
    val ground = Shiori.colors.background
    Box(Modifier.fillMaxWidth()) {
        // The colours under the avatars: the first book in progress, or the first of any rail.
        val backdrop = (shelf.reading.firstOrNull() ?: shelf.favorites.firstOrNull() ?: shelf.finished.firstOrNull() ?: shelf.pile.firstOrNull())?.book?.book?.coverURL
        // iOS's 760 points raised by 300: what is left of it below the bar.
        CoverBackdrop(backdrop, Modifier.fillMaxWidth().height(top + 460.dp), fadeHeight = 160.dp, ground = ground)
        Column(Modifier.fillMaxWidth().padding(top = top + 4.dp, bottom = pageEndRoom()), verticalArrangement = Arrangement.spacedBy(30.dp)) {
            ShioriTheme(dark = true) {
                // Over the rails, so a welcome's confetti fall in front of them.
                Column(Modifier.zIndex(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    FriendAvatarPicker(
                        friends.map { FriendAvatarItem(it.userId, it.displayName, it.avatar) },
                        selected,
                        welcomed = welcomed,
                        onRemove = { send(FriendsAction.Remove(it)) },
                    ) { send(FriendsAction.Toggle(it)) }
                    AnimatedVisibility(soleFriend != null, enter = fadeIn(), exit = fadeOut()) {
                        Column(Modifier.padding(horizontal = 20.dp)) {
                            LinkRow("book.pages", L("Livres")) { soleFriend?.let { send(FriendsAction.OpenLibrary(it)) } }
                            LinkRow("square.stack", L("Séries")) { soleFriend?.let { send(FriendsAction.OpenSeries(it)) } }
                        }
                    }
                }
            }
            Rails(shelf, isOne = soleFriend != null, send)
        }
    }
}

/** One friend shown speaks of them in the singular, several in the plural. */
@Composable
private fun Rails(shelf: FriendsShelf, isOne: Boolean, send: (FriendsAction) -> Unit) {
    Rail(L("Lecture en cours"), shelf.reading, PosterLabel.Context.RECENT, isOne, send)
    // The title says they are hearted: no heart, no line on the covers.
    Rail(L("Coups de cœur récents"), shelf.favorites, null, isOne, send)
    Rail(L("Terminés récemment"), shelf.finished, PosterLabel.Context.READ, isOne, send)
    Rail(if (isOne) L("Sur sa pile") else L("Sur leur pile"), shelf.pile, PosterLabel.Context.PILE, isOne, send)
}

@Composable
private fun Rail(title: String, entries: List<FriendsShelfEntry>, context: PosterLabel.Context?, isOne: Boolean, send: (FriendsAction) -> Unit) {
    if (entries.isEmpty()) return
    FriendsRail(
        title,
        entries.map { entry ->
            FriendsRailItem(
                entry.id,
                entry.book.book,
                context?.let { PosterLabel.of(entry.book.book, it) } ?: PosterLabel(caption = ""),
                if (isOne) null else entry.friendName ?: L("Un lecteur"),
                entry.book.ownerAvatar,
            )
        },
    ) { item -> entries.firstOrNull { it.id == item.id }?.let { send(FriendsAction.OpenBook(it)) } }
}

/** A row of the Library's ways in, as its "Livres" and "Séries". */
@Composable
private fun LinkRow(symbol: String, title: String, onClick: () -> Unit) {
    val colors = Shiori.colors
    Box(Modifier.fillMaxWidth().height(52.dp).plainClickable(onClick = onClick)) {
        Row(Modifier.fillMaxWidth().align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) { Icon(Symbol(symbol), null, Modifier.size(22.dp), tint = colors.label) }
            Text(title, style = Shiori.type.title3, color = colors.label, modifier = Modifier.weight(1f))
            Icon(Symbol("chevron.right"), null, Modifier.size(16.dp), tint = colors.tertiaryLabel)
        }
        ShioriDivider(Modifier.align(Alignment.BottomStart).padding(start = 44.dp))
    }
}

@Preview(showBackground = true)
@Composable
private fun FriendsPagePreview() = PreviewSurface(dark = true) {
    FriendsPage(FriendsFixtures.friends, emptyList(), FriendsFixtures.shelf, null, null, hasNoFriend = false, isWaiting = false, loadFailed = null, isInviting = false) {}
}

@Preview(showBackground = true)
@Composable
private fun FriendsPageOneFriendPreview() = PreviewSurface(dark = true) {
    FriendsPage(
        FriendsFixtures.friends, listOf("sophie"), FriendsFixtures.shelf.narrowed(listOf("sophie")), FriendsFixtures.friends[1], null,
        hasNoFriend = false, isWaiting = false, loadFailed = null, isInviting = false,
    ) {}
}

@Preview(showBackground = true)
@Composable
private fun FriendsPageNoFriendPreview() = PreviewSurface(dark = true) {
    FriendsPage(emptyList(), emptyList(), FriendsShelf(), null, DebugFixtures.myShelf, hasNoFriend = true, isWaiting = false, loadFailed = null, isInviting = false) {}
}
