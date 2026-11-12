package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** "L'IA prépare la fiche" on a turning field of colours, while the AI writes a book's record. */
@Composable
fun GeneratingPill() {
    val transition = rememberInfiniteTransition(label = "generating")
    val turn by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(3400, easing = LinearEasing)), label = "turn")
    val breath by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(1000), RepeatMode.Reverse), label = "breath")
    val c = Shiori.colors
    Box(Modifier.clip(CircleShape)) {
        Box(
            Modifier
                .matchParentSize()
                .rotate(turn)
                .background(Brush.sweepGradient(listOf(c.cyan, c.blue, c.purple, c.pink, c.orange, c.cyan))),
        )
        Text(
            L("L'IA prépare la fiche"),
            style = Shiori.type.subheadline.copy(
                fontWeight = FontWeight.SemiBold,
                shadow = Shadow(Color.White.copy(alpha = 0.7f + 0.3f * breath), Offset.Zero, 6f + 4f * breath),
            ),
            color = Color.White,
            maxLines = 1,
            modifier = Modifier.background(Color.Black.copy(alpha = 0.15f), CircleShape).padding(horizontal = 14.dp, vertical = 7.dp),
        )
    }
}

/** The pill at the foot of a page while `isGenerating`, rising in and fading out. */
@Composable
fun BoxScope.GeneratingPillHost(isGenerating: Boolean) {
    AnimatedVisibility(
        isGenerating,
        Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 12.dp),
        enter = fadeIn() + scaleIn(initialScale = 0.6f),
        exit = fadeOut() + scaleOut(targetScale = 0.9f),
    ) { GeneratingPill() }
}

@Preview(showBackground = true)
@Composable
private fun GeneratingPillPreview() = PreviewSurface {
    Row(Modifier.padding(16.dp)) { GeneratingPill() }
}
