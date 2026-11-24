package com.polyforms.shiori.features.friends

import androidx.compose.runtime.Composable

/**
 * The old invitation sheet, now the system's share sheet straight away, as on iOS
 * ([SharesInvitation]). Kept only for the callers other lots have not moved yet; the Friends lot
 * deletes it with its last caller.
 */
@Deprecated("Use SharesInvitation", ReplaceWith("SharesInvitation(invitation, onDismiss)"))
@Composable
fun InvitationSheet(invitation: FriendInvitation, @Suppress("UNUSED_PARAMETER") myShelf: FriendProfile? = null, onDismiss: () -> Unit) =
    SharesInvitation(invitation, onDismiss)
