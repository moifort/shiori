package com.polyforms.shiori.features.listening.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.listening.ListeningTitlePreview
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * An audiobook's square cover, as the player draws it, or a neutral square with headphones while
 * it loads or when there is none. Round in the accessory, where it follows the capsule's curve.
 */
@Composable
fun PlayerArtwork(url: String?, size: Dp, modifier: Modifier = Modifier, cornerRadius: Dp = 8.dp, isRound: Boolean = false) {
    val placeholder: @Composable () -> Unit = {
        Box(Modifier.fillMaxSize().background(Shiori.colors.quaternaryLabel), contentAlignment = Alignment.Center) {
            Icon(Symbol("headphones"), null, Modifier.size(size * 0.4f), tint = Shiori.colors.secondaryLabel)
        }
    }
    Box(
        modifier
            .size(size)
            .clip(if (isRound) CircleShape else RoundedCornerShape(cornerRadius))
            .clearAndSetSemantics {},
    ) {
        if (url != null) CoverImage(url, Modifier.fillMaxSize(), loading = placeholder, fallback = placeholder) else placeholder()
    }
}

@Preview(showBackground = true)
@Composable
private fun PlayerArtworkPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        PlayerArtwork(ListeningTitlePreview.coverURL, 120.dp, cornerRadius = 12.dp)
        PlayerArtwork(null, 120.dp, cornerRadius = 12.dp)
        PlayerArtwork(ListeningTitlePreview.coverURL, 48.dp, isRound = true)
    }
}
