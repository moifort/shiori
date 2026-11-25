package com.polyforms.shiori.features.friends

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.AppRouter
import com.polyforms.shiori.TabSelection
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.friends.components.pages.FriendsAction
import com.polyforms.shiori.features.friends.components.pages.FriendsPage
import com.polyforms.shiori.features.friends.components.pages.PastedInvitationAction
import com.polyforms.shiori.features.friends.components.pages.PastedInvitationSheet
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScrollAwayBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.delay

/**
 * The Amis tab, connected: loads the friends and the rails for the friends picked, opens a book,
 * one friend's library and series, the invitation, and hands the rest to [FriendsPage].
 *
 * The tab opens on what it last showed for the same pick, brought up to date silently underneath.
 * [friendRequest] is a friend another tab asked for: the page narrowed to them alone, back at its
 * top. [welcomedFriend] is the friend an invitation just joined: welcomed once they are in the row,
 * then let go. Both are cleared through [onFriendShown].
 */
@Composable
fun FriendsScreen(friendRequest: String?, welcomedFriend: String?, client: FriendsClient = FriendsClient.live, onFriendShown: () -> Unit) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { FriendsViewModel(client, scope) }
    val navigator = currentNavigator
    val bar = rememberScrollAwayState()

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    // A friend added or a book taken changes what the rails say: asked again on the next look.
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }
    LaunchedEffect(friendRequest) {
        val friendId = friendRequest ?: return@LaunchedEffect
        navigator.popToRoot()
        if (welcomedFriend == null) onFriendShown()
        viewModel.show(friendId)
    }

    // The friend to welcome, once they are among the friends shown; the welcome stops after the burst.
    val welcomed = welcomedFriend?.takeIf { id -> viewModel.friends.any { it.userId == id } }
    LaunchedEffect(welcomed) {
        if (welcomed == null) return@LaunchedEffect
        delay(3_000)
        onFriendShown()
    }

    Box(Modifier.fillMaxSize()) {
        FriendsPage(
            friends = viewModel.friends,
            selected = viewModel.picked,
            shelf = viewModel.shelf,
            soleFriend = viewModel.soleFriend,
            myShelf = viewModel.myShelf,
            hasNoFriend = viewModel.hasNoFriend,
            isWaiting = viewModel.isEmpty && !viewModel.loaded && viewModel.loadFailed == null,
            loadFailed = if (viewModel.isEmpty) viewModel.loadFailed else null,
            isInviting = viewModel.isInviting,
            welcomed = welcomed,
            scroll = bar.connection,
        ) { action ->
            when (action) {
                is FriendsAction.Toggle -> viewModel.toggle(action.friendId)
                is FriendsAction.OpenBook -> navigator.push {
                    FriendBookScreen(action.entry.friendId, action.entry.book.id, action.entry.friendName ?: L("Un lecteur"))
                }
                is FriendsAction.OpenMyBook -> navigator.push { BookScreen(action.book.id) }
                is FriendsAction.OpenLibrary -> navigator.push { FriendLibraryScreen(action.friend.userId, action.friend.displayName) }
                is FriendsAction.OpenSeries -> navigator.push { FriendSeriesListScreen(action.friend.userId, action.friend.displayName) }
                FriendsAction.Invite -> viewModel.invite()
                is FriendsAction.Remove -> viewModel.remove(action.friendId)
                FriendsAction.Refresh -> viewModel.load()
            }
        }
        ScrollAwayBar(L("Amis"), bar) {
            if (!viewModel.hasNoFriend) AsyncToolbarButton(L("Inviter"), "person.badge.plus") { viewModel.invite() }
        }
    }
    SharesInvitation(viewModel.invitation) { viewModel.invitation = null }
    viewModel.errorMessage?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.errorMessage = null }) }
}

/**
 * What the app does over every tab for the friends: an invitation a tapped link — or Google Play,
 * or a pasted link — brought is taken up at once, and the Amis tab opens on the friend arriving
 * among the others. The first opening after onboarding asks Play for the invitation the install
 * came from, and, when it has none, offers once to paste the link the invitation page copied.
 */
@Composable
fun FriendsOverlays(router: AppRouter, client: FriendsClient = FriendsClient.live) {
    val context = LocalContext.current
    var invitationError by remember { mutableStateOf<String?>(null) }
    var offersPastedInvitation by remember { mutableStateOf(false) }

    LaunchedEffect(router.invitation) {
        val request = router.invitation ?: return@LaunchedEffect
        router.invitation = null
        // Accepting changes no library, so the Amis tab is told here to ask again.
        try {
            val friend = client.accept(request.code)
            DataChanges.post(null)
            router.selectedTab = TabSelection.FRIENDS
            router.welcomedFriend = friend.userId
        } catch (error: Throwable) {
            if (!isCancellation(error)) invitationError = reportError(error)
        }
    }

    LaunchedEffect(Unit) {
        if (!PastedInvitation.takePending(context) || router.invitation != null) return@LaunchedEffect
        val code = InstallInvitation.code(context)
        when {
            code != null -> router.invitation = InvitationRequest(code)
            PastedInvitation.clipboardHoldsText(context) -> offersPastedInvitation = true
        }
    }

    if (offersPastedInvitation) {
        ShioriSheet({ offersPastedInvitation = false }) { dismiss ->
            PastedInvitationSheet { action ->
                if (action == PastedInvitationAction.PASTE) {
                    val code = PastedInvitation.pastedText(context)?.let(InvitationLink::code)
                    if (code != null) router.invitation = InvitationRequest(code) else invitationError = L("Ce lien n'est pas une invitation Shiori.")
                }
                dismiss()
            }
        }
    }
    invitationError?.let { ShioriAlert(L("Invitation refusée"), it, onDismiss = { invitationError = null }) }
}
