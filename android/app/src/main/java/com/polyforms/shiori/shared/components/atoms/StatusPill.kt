package com.polyforms.shiori.shared.components.atoms

import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * What the reader decided of a page's subject, said in words in its hero — "Pas intéressé" —
 * while the button under it says what a tap does. White on glass, as every pill over a cover.
 */
@Composable
fun StatusPill(text: String, symbol: String, modifier: Modifier = Modifier) {
    Row(
        modifier
            .background(Color.White.copy(alpha = 0.18f), CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Symbol(symbol), null, Modifier.size(13.dp), tint = Color.White)
        Text(text, style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1)
    }
}

/** A status a hero names, as [StatusPill] draws it. */
data class HeroStatus(val text: String, val symbol: String) {
    companion object {
        /** A discovery the reader turned down. */
        val notInterested: HeroStatus get() = HeroStatus(L("Pas intéressé"), "eye.slash")
    }
}

/**
 * How a page fades to black and white once the reader turns its book down or stops following its
 * saga: slow enough to watch the colour go.
 */
fun <T> setAsideAnimation() = tween<T>(durationMillis = 1200)

@Preview(showBackground = true)
@Composable
private fun StatusPillPreview() = PreviewSurface {
    Box(Modifier.background(Brush.verticalGradient(listOf(Color(0xFF2E7D32), Color(0xFF1B5E20)))).padding(16.dp)) {
        StatusPill(HeroStatus.notInterested.text, HeroStatus.notInterested.symbol)
    }
}
