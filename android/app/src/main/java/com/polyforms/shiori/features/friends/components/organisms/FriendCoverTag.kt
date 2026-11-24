package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarHero
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ultraThinDark

/**
 * Whose book it is, in the top corner of a cover: the friend's avatar and first name on a dark
 * glass capsule, white like every label on a cover. [isLarge]: the larger pill a friend's book page
 * sets over its title.
 */
@Composable
fun FriendCoverTag(name: String, avatar: AccountAvatar, modifier: Modifier = Modifier, isLarge: Boolean = false) {
    Row(
        modifier
            .height(if (isLarge) 40.dp else 26.dp)
            .ultraThinDark(CircleShape)
            .background(Color.Black.copy(alpha = 0.35f), CircleShape)
            .border(0.5.dp, Color.White.copy(alpha = 0.3f), CircleShape)
            .padding(start = 4.dp, end = if (isLarge) 15.dp else 9.dp),
        horizontalArrangement = Arrangement.spacedBy(if (isLarge) 8.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AccountAvatarView(avatar, name, if (isLarge) 32.dp else 18.dp)
        Text(
            name,
            style = if (isLarge) Shiori.type.headline else Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
            color = Color.White,
            maxLines = 1,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun FriendCoverTagPreview() = PreviewSurface {
    Column(Modifier.background(Color(0xFFE08A2C)).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        FriendCoverTag("Sophie", AccountAvatar.Hero(AvatarHero.ALICE))
        FriendCoverTag("Sophie", AccountAvatar.Hero(AvatarHero.ALICE), isLarge = true)
    }
}
