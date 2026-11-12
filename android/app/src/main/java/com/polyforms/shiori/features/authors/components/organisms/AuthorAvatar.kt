package com.polyforms.shiori.features.authors.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.shared.CoverImage
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A person's portrait in a circle, or their initials on a slate gradient. */
@Composable
fun AuthorAvatar(initials: String, portraitURL: String?, modifier: Modifier = Modifier, size: Dp = 40.dp) {
    Box(modifier.size(size).clip(CircleShape)) {
        val monogram = @Composable { Monogram(initials, size) }
        if (portraitURL != null) {
            CoverImage(portraitURL, Modifier.fillMaxSize(), loading = monogram, fallback = monogram)
        } else {
            monogram()
        }
    }
}

@Composable
private fun Monogram(initials: String, size: Dp) {
    Box(
        Modifier.fillMaxSize().background(
            Brush.linearGradient(listOf(Color(0.23f, 0.29f, 0.35f), Color(0.12f, 0.16f, 0.2f))),
        ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            initials,
            style = TextStyle(fontSize = maxOf(13f, size.value / 3.4f).sp, fontWeight = FontWeight.SemiBold),
            color = Color.White.copy(alpha = 0.9f),
        )
    }
}

@Composable
fun FollowedAuthor.Avatar(modifier: Modifier = Modifier, size: Dp = 40.dp) = AuthorAvatar(initials, portraitURL, modifier, size)

@Preview(showBackground = true)
@Composable
private fun AuthorAvatarPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        AuthorAvatar("PR", null)
        AuthorAvatar("UL", null, size = 93.dp)
    }
}
