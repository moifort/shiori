package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.friends.components.pages.SharedAction
import com.polyforms.shiori.features.friends.components.pages.SharedPage
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.PlainTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.copyText
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.platform.shareText
import kotlinx.coroutines.launch

/**
 * The Partagé screen, connected: loads the reader's shelf and their friends, opens a friend's
 * page, a book, the invitation flows, and hands the rest to `SharedPage`.
 */
@Composable
fun SharedScreen(client: FriendsClient = FriendsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { SharedViewModel(client, scope) }
    val navigator = currentNavigator
    val context = LocalContext.current
    var showAccept by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf<Friend?>(null) }

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    // A book taken from a friend changes their shelves, and their counts move when they write.
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load() } }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        SharedPage(
            viewModel.myShelf,
            viewModel.friends,
            isWaiting = viewModel.isEmpty && !viewModel.loaded,
            loadFailed = if (viewModel.isEmpty && !viewModel.isLoading) viewModel.loadFailed else null,
            isInviting = viewModel.isInviting,
        ) { action ->
            when (action) {
                // A cover opens its book as the friend's page opens it; the reader's own covers
                // open their own record.
                is SharedAction.OpenBook -> navigator.push {
                    val friend = action.friend
                    if (friend != null) FriendBookScreen(friend.userId, action.book.id, friend.displayName) else BookScreen(action.book.id)
                }
                SharedAction.OpenMyPage -> viewModel.myShelf?.let { shelf -> navigator.push { FriendProfileScreen(Friend.seenByFriends(shelf), preview = shelf) } }
                is SharedAction.OpenFriend -> navigator.push { FriendProfileScreen(action.friend) }
                SharedAction.Invite -> viewModel.invite()
                SharedAction.EnterCode -> showAccept = true
                is SharedAction.AskToRemove -> removing = action.friend
                is SharedAction.ShareFavorites -> context.shareText(action.text)
                is SharedAction.CopyFavorites -> context.copyText(action.text)
                SharedAction.Refresh -> viewModel.load()
            }
        }
        ScreenBar(onBack = null)
    }

    // The invitation is shared the moment it comes back: the reader tapped "invite".
    viewModel.invitation?.let { InvitationSheet(it, viewModel.myShelf) { viewModel.invitation = null } }
    if (showAccept) {
        var code by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showAccept = false },
            title = { Text(L("J'ai reçu une invitation"), style = Shiori.type.headline) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(L("Collez le code à huit caractères, ou le lien que l'on vous a envoyé."), style = Shiori.type.subheadline)
                    PlainTextField(
                        code,
                        { code = it },
                        L("Code ou lien"),
                        Modifier.fillMaxWidth().background(Shiori.colors.tertiaryFill, RoundedCornerShape(10.dp)).padding(12.dp),
                        capitalization = KeyboardCapitalization.Characters,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showAccept = false
                    scope.launch { viewModel.accept(code) }
                }) { Text(L("Accepter"), color = Shiori.colors.accent) }
            },
            dismissButton = { TextButton(onClick = { showAccept = false }) { Text(L("Annuler"), color = Shiori.colors.accent) } },
            containerColor = Shiori.colors.secondaryGroupedBackground,
        )
    }
    viewModel.accepted?.let { name ->
        ShioriAlert(
            L("Vous partagez vos bibliothèques"),
            L("%@ voit votre bibliothèque, et vous voyez la sienne.", name),
            onDismiss = { viewModel.accepted = null },
            confirm = L("Parfait"),
        )
    }
    viewModel.errorMessage?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.errorMessage = null }) }
    removing?.let { friend ->
        ConfirmationSheet(
            L("Ne plus partager avec %@ ?", friend.displayName),
            listOf(ConfirmationChoice(L("Retirer"), destructive = true) { scope.launch { viewModel.remove(friend) } }),
            L("Vous ne verrez plus sa bibliothèque, et il ne verra plus la vôtre."),
        ) { removing = null }
    }
}
