package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.features.friends.components.organisms.SharedSummary
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.shareText
import com.polyforms.shiori.shared.reportError

/**
 * The invitation, ready to send. The link is what gets shared — it lands on a page that says
 * what to do with the code — and the code is spelled out for reading down a phone.
 */
@Composable
fun InvitationSheet(invitation: FriendInvitation, myShelf: FriendProfile? = null, onDismiss: () -> Unit) {
    val context = LocalContext.current
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(L("Inviter un ami"), leading = { ToolbarIconButton(L("Fermer"), "xmark", onClick = dismiss) })
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Icon(Symbol("person.2.badge.key"), null, Modifier.size(44.dp), tint = Shiori.colors.accent)
            SelectionContainer {
                Text(
                    invitation.code,
                    style = Shiori.type.largeTitle.copy(fontFamily = FontFamily.Monospace, letterSpacing = 6.sp),
                    color = Shiori.colors.label,
                    modifier = Modifier.background(Shiori.colors.tertiaryFill, RoundedCornerShape(14.dp)).padding(horizontal = 20.dp, vertical = 14.dp),
                )
            }
            if (myShelf != null) SharedSummary(Friend.seenByFriends(myShelf))
            ShioriButton(L("Envoyer l'invitation"), symbol = "square.and.arrow.up", large = true, fillWidth = true) {
                context.shareText(L("Je t'ouvre ma bibliothèque sur Shiori. Code : %@", invitation.code) + "\n" + invitation.url)
            }
        }
    }
}

/** An invitation the reader arrived on by tapping a link, waiting to be taken up. */
data class InvitationRequest(val code: String)

/**
 * What a tapped invitation link opens on. It asks before it accepts: the link came from
 * somewhere the reader does not control, and accepting opens their library to whoever sent it.
 */
@Composable
fun InvitationAcceptSheet(request: InvitationRequest, onDismiss: () -> Unit, client: FriendsClient = FriendsClient.live) {
    var myShelf by remember { mutableStateOf<FriendProfile?>(null) }
    var accepted by remember { mutableStateOf<Friend?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    // The summary is a nicety: the invitation can be accepted without it.
    LaunchedEffect(Unit) { myShelf = runCatching { client.myShelf() }.getOrNull() }
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(L("Invitation"), leading = { ToolbarIconButton(L("Fermer"), "xmark", onClick = dismiss) })
        InvitationAcceptPage(
            myShelf,
            accepted,
            onAccept = {
                try {
                    accepted = client.accept(request.code)
                    // Accepting changes no library: the Partagé screen is told here.
                    DataChanges.post(null)
                } catch (error: Throwable) {
                    if (!isCancellation(error)) errorMessage = reportError(error)
                }
            },
            onClose = dismiss,
        )
    }
    errorMessage?.let { ShioriAlert(L("Invitation refusée"), it, onDismiss = { errorMessage = null }) }
}

/** An invitation opened from a link: what accepting shares, and once accepted, the friend. */
@Composable
fun InvitationAcceptPage(myShelf: FriendProfile?, accepted: Friend?, onAccept: suspend () -> Unit, onClose: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 28.dp).padding(bottom = 28.dp).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Icon(Symbol(if (accepted == null) "person.2.badge.key" else "checkmark.seal.fill"), null, Modifier.size(46.dp), tint = Shiori.colors.accent)
        Text(
            if (accepted == null) L("Vous partagerez vos livres") else L("Vous partagez maintenant vos livres"),
            style = Shiori.type.title3.copy(fontWeight = FontWeight.SemiBold),
            color = Shiori.colors.label,
            textAlign = TextAlign.Center,
        )
        val shown = accepted ?: myShelf?.let { Friend.seenByFriends(it) }
        if (shown != null) Box(Modifier.fillMaxWidth()) { SharedSummary(shown, heading = null) }
        if (accepted != null) {
            ShioriButton(L("Parfait"), large = true, fillWidth = true) { onClose() }
        } else {
            ShioriButton(L("Accepter"), large = true, fillWidth = true) { onAccept() }
            ShioriButton(L("Pas maintenant"), kind = ButtonKind.PLAIN) { onClose() }
        }
    }
}
