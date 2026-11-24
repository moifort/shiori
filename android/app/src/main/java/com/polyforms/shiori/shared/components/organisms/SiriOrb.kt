package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.R
import com.polyforms.shiori.shared.components.styles.reduceMotion
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sqrt

private val siriRed = Color(1f, 0.16f, 0.33f)
private val siriBlue = Color(0.18f, 0.42f, 1f)
private val siriCyan = Color(0.37f, 0.95f, 1f)
private val siriGreen = Color(0.18f, 0.88f, 0.62f)

/** One pale layer of the orb: its artwork, its size in points, and how it turns and tips. */
private class OrbLayer(
    val image: Int,
    val width: Float,
    val height: Float,
    val color: Color?,
    val spin: Pair<Float, Float>,
    val tilt: Float,
    val axis: (Float) -> Triple<Float, Float, Float>,
    val alpha: Float = 0.8f,
    val grow: Float = 1f,
)

private fun mix(a: Float, b: Float, t: Float) = a + (b - a) * t

private val layers = listOf(
    OrbLayer(R.drawable.siri_pink_left, 294f, 226f, siriRed, -360f to 180f, 0f, { Triple(0f, 0f, 1f) }, 0.9f, 1.35f),
    OrbLayer(R.drawable.siri_pink_top, 91f, 151f, siriRed, 320f to -360f, 0f, { Triple(0f, 0f, 1f) }, 0.9f, 1.4f),
    OrbLayer(R.drawable.siri_blue_right, 269f, 304f, siriBlue, -360f to 420f, 70f, { Triple(1f, 0f, mix(-5f, 15f, it)) }),
    OrbLayer(R.drawable.siri_blue_middle, 220f, 262f, siriBlue, -360f to 420f, 72f, { Triple(mix(1f, 5f, it), 0f, 0f) }),
    OrbLayer(R.drawable.siri_green_right, 286f, 217f, siriGreen, -180f to 480f, 30f, { Triple(1f, mix(-1f, 1f, it), 0f) }, 0.6f),
    OrbLayer(R.drawable.siri_green_left, 286f, 217f, siriGreen, 240f to -480f, 74f, { Triple(1f, mix(-5f, 15f, it), 0f) }),
    OrbLayer(R.drawable.siri_intersect, 274f, 260f, siriCyan, 30f to -420f, 70f, { Triple(1f, 1f, 1f) }, 0.42f),
    OrbLayer(R.drawable.siri_bottom_pink, 74f, 144f, siriRed, 400f to -360f, 74f, { Triple(5f, mix(1f, -45f, it), 0f) }),
)

/**
 * The AI at work, as Siri's orb: red, blue and green lobes of light turn and tip, edge-on lobes
 * reading as ribbons, and the crossings burn to white. Shown wherever a reader waits on the
 * model: a shelf being searched, a cover, a link or a title being read.
 *
 * Ported from the iOS `SiriOrb` and its vector layers (rendered to PNG here): each pale layer is
 * tinted to a pure Siri colour and added as light, straight on black, centred and clipped round.
 * Compose has no 3D rotation of a drawn image, so a layer's tilt about an axis is drawn as its
 * flattening along that axis. The phase eases back and forth between two poses, so the loop has
 * no seam; with animations off it holds one frame. Drawn over black, it belongs on a dark page.
 */
@Composable
fun SiriOrb(modifier: Modifier = Modifier, size: Dp = 300.dp) {
    val still = reduceMotion()
    var phase by remember { mutableFloatStateOf(0.5f) }
    LaunchedEffect(still) {
        if (still) return@LaunchedEffect
        val start = withFrameMillis { it }
        // Seconds for one pose-A → pose-B traversal; the full loop takes twice this.
        val period = 12f
        while (true) {
            withFrameMillis { now ->
                val cycle = (now - start) / 1000f / (period * 2) + 0.25f
                phase = ((1 - cos(2 * PI * cycle)) / 2).toFloat()
            }
        }
    }
    val images = layers.map { ImageBitmap.imageResource(it.image) }
    val highlight = ImageBitmap.imageResource(R.drawable.siri_highlight)
    Canvas(
        modifier
            .size(size)
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .clearAndSetSemantics {},
    ) {
        val t = phase
        val radius = this.size.minDimension / 2
        // The artwork is 640 points wide, its largest lobe about 520: fitted to the footprint.
        val unit = this.size.minDimension / 520f
        // Straight on black, clipped round, as iOS's `clipShape(Circle().scale(0.9))`.
        clipPath(Path().apply { addOval(Rect(center, radius * 0.9f)) }) {
        drawCircle(Color.Black, radius * 0.9f)
        layers.forEachIndexed { index, layer ->
            val (ax, ay, az) = layer.axis(t)
            val norm = sqrt(ax * ax + ay * ay + az * az).coerceAtLeast(0.0001f)
            val tilt = Math.toRadians(layer.tilt.toDouble())
            // A turn about the x axis flattens the layer vertically, about y horizontally.
            val squashY = 1 - (1 - abs(cos(tilt)).toFloat()) * abs(ax) / norm
            val squashX = 1 - (1 - abs(cos(tilt)).toFloat()) * abs(ay) / norm
            withTransform({
                scale(squashX, squashY, center)
                rotate(mix(layer.spin.first, layer.spin.second, t), center)
                scale(layer.grow * unit, layer.grow * unit, center)
            }) {
                drawLayer(images[index], layer.width, layer.height, layer.color, layer.alpha)
            }
        }
        withTransform({
            rotate(mix(360f, 250f, t), center)
            scale(0.6f * unit, 0.6f * unit, center)
        }) { drawLayer(highlight, 239f, 266f, null, 0.3f) }
        }
        // Softens the sphere's edge into the page.
        drawCircle(
            Brush.radialGradient(0f to Color.Black, 0.8f to Color.Black, 1f to Color.Transparent, center = center, radius = radius),
            radius,
            blendMode = BlendMode.DstIn,
        )
    }
}

/** A layer at its own size in points, centred, added as light. */
private fun DrawScope.drawLayer(image: ImageBitmap, width: Float, height: Float, color: Color?, alpha: Float) {
    val w = width.toInt()
    val h = height.toInt()
    drawImage(
        image,
        dstOffset = IntOffset((center.x - w / 2f).toInt(), (center.y - h / 2f).toInt()),
        dstSize = IntSize(w, h),
        alpha = alpha,
        colorFilter = color?.let { ColorFilter.tint(it, BlendMode.Modulate) },
        blendMode = BlendMode.Plus,
    )
}

@Preview(showBackground = true)
@Composable
private fun SiriOrbPreview() = PreviewSurface(dark = true) {
    Box(Modifier.background(Color.Black), contentAlignment = Alignment.Center) { SiriOrb(size = 240.dp) }
}
