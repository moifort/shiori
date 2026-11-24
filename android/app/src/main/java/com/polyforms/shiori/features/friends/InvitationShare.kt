package com.polyforms.shiori.features.friends

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.shared.L

/**
 * Sends an invitation the moment it exists: the system's share sheet, straight over whatever
 * screen asked, with the message and the link and nothing else.
 *
 * No screen of Shiori's own comes first. The link carries everything — the friend taps it and the
 * app does the rest — so a code to read out, or a summary of what will be shared, would be a step
 * between the reader and the friend they already had in mind.
 */
object InvitationShare {
    /** The words that go with the link, and the title the share sheet shows. */
    val message: String get() = L("Je t'ouvre ma bibliothèque sur Shiori")

    fun present(context: Context, invitation: FriendInvitation) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, "$message\n${invitation.url}")
            putExtra(Intent.EXTRA_SUBJECT, message)
            putExtra(Intent.EXTRA_TITLE, message)
        }
        context.startActivity(Intent.createChooser(send, message).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

/** Shares the invitation as soon as one is set, and lets it go: the screen asks for it, the system's sheet sends it. */
@Composable
fun SharesInvitation(invitation: FriendInvitation?, onShared: () -> Unit) {
    val context = LocalContext.current
    LaunchedEffect(invitation?.code) {
        val value = invitation ?: return@LaunchedEffect
        onShared()
        InvitationShare.present(context, value)
    }
}
