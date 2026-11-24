package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

private const val DURATION = 2.2f

private val confettiColors = listOf(
    Color(0xFFFF9500), Color(0xFF34C759), Color(0xFF007AFF), Color(0xFFFF2D55),
    Color(0xFFFFCC00), Color(0xFFAF52DE), Color(0xFF32ADE6), Color.White,
)

/** One piece of confetti: where it is thrown, and how it looks and turns. Sizes in dp. */
private class Piece(
    val dx: Float,
    val dy: Float,
    val width: Float,
    val height: Float,
    val color: Color,
    val isRound: Boolean,
    val angle: Float,
    val spin: Float,
    val flutter: Float,
) {
    companion object {
        fun random(reach: Float): Piece {
            val direction = Random.nextDouble(0.0, 2 * PI)
            val speed = Random.nextDouble(0.45, 1.0).toFloat() * reach * 3.2f
            val isRound = Random.nextBoolean() && Random.nextBoolean()
            val side = Random.nextDouble(5.0, 7.0).toFloat()
            return Piece(
                // A little more up than down, so the burst rises before it falls.
                dx = cos(direction).toFloat() * speed,
                dy = sin(direction).toFloat() * speed - reach * 0.9f,
                width = if (isRound) side else Random.nextDouble(4.0, 6.0).toFloat(),
                height = if (isRound) side else Random.nextDouble(9.0, 13.0).toFloat(),
                color = confettiColors.random(),
                isRound = isRound,
                angle = Random.nextDouble(0.0, 180.0).toFloat(),
                spin = Random.nextDouble(-540.0, 540.0).toFloat(),
                flutter = Random.nextDouble(4.0, 10.0).toFloat(),
            )
        }
    }
}

/**
 * A burst of confetti from one point, once: the pieces fly out, turn, fall and fade within two
 * seconds, then nothing is drawn. It catches no touch. One canvas draws every piece per frame.
 */
@Composable
fun ConfettiBurst(modifier: Modifier = Modifier, reach: Dp = 170.dp, count: Int = 64) {
    val pieces = remember { List(count) { Piece.random(reach.value) } }
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween((DURATION * 1000).toInt(), easing = LinearEasing)) }
    Canvas(modifier.fillMaxSize().clearAndSetSemantics {}) {
        val p = progress.value
        if (p <= 0f || p >= 1f) return@Canvas
        val t = p * DURATION
        val centre = Offset(size.width / 2, size.height / 2)
        val unit = density
        pieces.forEach { piece ->
            // Thrown out fast, slowed by the air, pulled down by gravity.
            val drag = (1 - exp(-3.2f * t)) / 3.2f
            val x = centre.x + piece.dx * drag * unit
            val y = centre.y + (piece.dy * drag + 140 * t * t) * unit
            val alpha = max(0f, 1 - max(0f, t - 1.1f) / 1.1f)
            // A strip flips as it turns: its width breathes with the spin.
            val flip = abs(cos(t * piece.flutter + piece.angle))
            val w = piece.width * flip * unit
            val h = piece.height * unit
            translate(x, y) {
                rotate(piece.spin * t + piece.angle, pivot = Offset.Zero) {
                    if (piece.isRound) {
                        drawOval(piece.color, Offset(-w / 2, -h / 2), Size(w, h), alpha = alpha)
                    } else {
                        drawRoundRect(piece.color, Offset(-w / 2, -h / 2), Size(w, h), CornerRadius(unit, unit), alpha = alpha)
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ConfettiBurstPreview() = PreviewSurface(dark = true) {
    Box(Modifier.size(360.dp).background(Color.Black), contentAlignment = Alignment.Center) {
        Box(Modifier.size(62.dp).background(Color.Gray, CircleShape))
        ConfettiBurst()
    }
}
