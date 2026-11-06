package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Symbol
import kotlin.math.cos
import kotlin.math.sin

private data class Bud(val diameter: Float, val speed: Float, val phase: Float)

private val buds = listOf(Bud(0.24f, 0.42f, 0f), Bud(0.18f, -0.31f, 2.1f), Bud(0.21f, 0.27f, 4.2f))

/** The AI at work: glass drops budding from a sparkled one over a turning glow. */
@Composable
fun AIGlassDrops(size: Dp = 220.dp) {
    var time by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { time = (it - start) / 1000f }
    }
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(size).blur(28.dp)) {
            val colors = listOf(Color(0.6f, 0.42f, 1f), Color(0.32f, 0.68f, 1f), Color(1f, 0.42f, 0.68f), Color(1f, 0.62f, 0.3f), Color(0.6f, 0.42f, 1f))
            rotate(time * 40f) { drawCircle(Brush.sweepGradient(colors), this.size.minDimension * 0.32f, alpha = 0.55f) }
        }
        Canvas(Modifier.size(size)) {
            val unit = this.size.minDimension
            val centre = center
            fun drop(at: Offset, diameter: Float) {
                val radius = unit * diameter / 2
                drawCircle(Brush.linearGradient(listOf(Color.White.copy(alpha = 0.34f), Color.White.copy(alpha = 0.08f)), at - Offset(radius, radius), at + Offset(radius, radius)), radius, at)
                drawCircle(Color.White.copy(alpha = 0.4f), radius, at, style = Stroke(1.2.dp.toPx()))
            }
            drop(centre, 0.40f)
            buds.forEach { bud ->
                val angle = bud.phase + time * bud.speed * 2 * Math.PI.toFloat()
                val distance = unit * (0.2f + 0.06f * sin(time * 1.3f + bud.phase))
                drop(Offset(centre.x + distance * cos(angle), centre.y + distance * sin(angle)), bud.diameter)
            }
        }
        Icon(Symbol("sparkles"), null, Modifier.size(size * 0.14f), tint = Color.White.copy(alpha = 0.92f))
    }
}
