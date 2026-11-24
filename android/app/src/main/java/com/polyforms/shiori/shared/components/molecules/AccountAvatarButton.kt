package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * The reader's avatar as a bar button, ringed as the TV app rings it: a rim of the same glass as
 * the buttons beside it, at their size, so the face stands off the page in light and dark alike.
 */
@Composable
fun AccountAvatarButton(avatar: AccountAvatar, firstName: String?, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(CircleShape)
            .glass(CircleShape)
            .plainClickable(onClick = onClick)
            .semantics {
                contentDescription = L("Réglages")
                role = Role.Button
            }
            .padding(3.dp),
    ) {
        AccountAvatarView(avatar, firstName, 38.dp)
    }
}

@Preview(showBackground = true)
@Composable
private fun AccountAvatarButtonPreview() = PreviewSurface {
    Box(Modifier.padding(16.dp)) { AccountAvatarButton(AccountAvatar.Tinted(AvatarColor.PINK), "Thibaut") {} }
}
