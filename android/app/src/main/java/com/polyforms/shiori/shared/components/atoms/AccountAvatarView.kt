package com.polyforms.shiori.shared.components.atoms

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.initials
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A reader's face, round: their initials, a colour, a hero, or their photo. */
@Composable
fun AccountAvatarView(avatar: AccountAvatar, firstName: String?, size: Dp = 40.dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size).clip(CircleShape), contentAlignment = Alignment.Center) {
        when (avatar) {
            AccountAvatar.Initials -> Monogram(firstName, size, null)
            is AccountAvatar.Tinted -> Monogram(firstName, size, avatar.color.tint.color())
            is AccountAvatar.Hero -> Image(
                painterResource(avatar.hero.imageRes),
                null,
                Modifier.size(size),
                contentScale = ContentScale.Crop,
            )
            is AccountAvatar.Photo -> CoverImage(
                avatar.url,
                Modifier.size(size),
                loading = { Monogram(firstName, size, null) },
                fallback = { Monogram(firstName, size, null) },
            )
            is AccountAvatar.PickedPhoto -> {
                val bitmap = remember(avatar.data) {
                    BitmapFactory.decodeByteArray(avatar.data, 0, avatar.data.size)?.asImageBitmap()
                }
                if (bitmap != null) {
                    Image(bitmap, null, Modifier.size(size), contentScale = ContentScale.Crop)
                } else {
                    Monogram(firstName, size, null)
                }
            }
        }
    }
}

@Composable
private fun Monogram(firstName: String?, size: Dp, tint: Color?) {
    val background = if (tint != null) {
        Brush.verticalGradient(listOf(tint.copy(alpha = 0.85f), tint))
    } else {
        Brush.verticalGradient(listOf(Color(0xFF9EA6B3), Color(0xFF666E7A)))
    }
    val letters = initials(firstName)
    val sp = with(LocalDensity.current) { (size * 0.42f).toSp() }
    Box(Modifier.size(size).background(background), contentAlignment = Alignment.Center) {
        if (letters.isEmpty()) {
            Icon(Symbol("person.fill"), null, Modifier.size(size * 0.55f).offset(y = size * 0.08f), tint = Color.White)
        } else {
            Text(letters, style = TextStyle(fontSize = sp, fontWeight = FontWeight.SemiBold, color = Color.White))
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun AccountAvatarViewPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        AccountAvatarView(com.polyforms.shiori.shared.account.AccountAvatar.Initials, "Camille")
        AccountAvatarView(com.polyforms.shiori.shared.account.AccountAvatar.Tinted(com.polyforms.shiori.shared.account.AvatarColor.PINK), "Léa")
        AccountAvatarView(com.polyforms.shiori.shared.account.AccountAvatar.Initials, null)
    }
}
