package com.polyforms.shiori.shared.components.organisms

import android.graphics.Bitmap
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import com.polyforms.shiori.shared.components.styles.rememberEffectClock
import kotlin.math.sin
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
    val hue: Float,
    val alpha: Float = 0.8f,
    val grow: Float = 1f,
)

private fun mix(a: Float, b: Float, t: Float) = a + (b - a) * t

private val layers = listOf(
    OrbLayer(R.drawable.siri_pink_left, 294f, 226f, siriRed, -360f to 180f, 0f, { Triple(0f, 0f, 1f) }, 8f, 0.9f, 1.35f),
    OrbLayer(R.drawable.siri_pink_top, 91f, 151f, siriRed, 320f to -360f, 0f, { Triple(0f, 0f, 1f) }, 8f, 0.9f, 1.4f),
    OrbLayer(R.drawable.siri_blue_right, 269f, 304f, siriBlue, -360f to 420f, 70f, { Triple(1f, 0f, mix(-5f, 15f, it)) }, 10f),
    OrbLayer(R.drawable.siri_blue_middle, 220f, 262f, siriBlue, -360f to 420f, 72f, { Triple(mix(1f, 5f, it), 0f, 0f) }, 10f),
    OrbLayer(R.drawable.siri_green_right, 286f, 217f, siriGreen, -180f to 480f, 30f, { Triple(1f, mix(-1f, 1f, it), 0f) }, 10f, 0.6f),
    OrbLayer(R.drawable.siri_green_left, 286f, 217f, siriGreen, 240f to -480f, 74f, { Triple(1f, mix(-5f, 15f, it), 0f) }, 10f),
    OrbLayer(R.drawable.siri_intersect, 274f, 260f, siriCyan, 30f to -420f, 70f, { Triple(1f, 1f, 1f) }, 12f, 0.42f),
    OrbLayer(R.drawable.siri_bottom_pink, 74f, 144f, siriRed, 400f to -360f, 74f, { Triple(5f, mix(1f, -45f, it), 0f) }, 8f),
)

/**
 * The AI at work, as Siri's orb: red, blue and green lobes of light turn and tip, edge-on lobes
 * reading as ribbons, and the crossings burn to white. Shown wherever a reader waits on the
 * model: a shelf being searched, a cover, a link or a title being read.
 *
 * Ported from the iOS `SiriOrb` and its vector layers (rendered to PNG here), layer for layer:
 * each pale layer is tinted to a pure Siri colour (`colorMultiply`), saturated by 1.6, its hue
 * swung by a few degrees with the phase, turned, then tipped in 3D about its axis and seen in
 * perspective as SwiftUI's `rotation3DEffect` draws it (the tilt is a true projective transform of
 * the layer, not a flattening), and added as light, straight on black, centred and clipped round.
 * The phase eases back and forth between two poses, so the loop has no seam; with animations off
 * it holds one frame. Every frame is drawn, never recomposed. Drawn over black, it belongs on a
 * dark page.
 */
@Composable
fun SiriOrb(modifier: Modifier = Modifier, size: Dp = 300.dp) {
    val still = reduceMotion()
    val clock = rememberEffectClock()
    val images = layers.map { ImageBitmap.imageResource(it.image).asAndroidBitmap() }
    val highlight = ImageBitmap.imageResource(R.drawable.siri_highlight).asAndroidBitmap()
    Canvas(
        modifier
            .size(size)
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .clearAndSetSemantics {},
    ) {
        // Seconds for one pose-A → pose-B traversal; the full loop takes twice this. Starts half-way.
        val period = 12f
        val t = if (still) 0.5f else ((1 - cos(2 * PI * (clock.value / (period * 2) + 0.25f))) / 2).toFloat()
        val radius = this.size.minDimension / 2
        // The artwork is 640 points wide, its largest lobe about 520: fitted to the footprint.
        val unit = this.size.minDimension / 520f
        // Straight on black, clipped round, as iOS's `clipShape(Circle().scale(0.9))`.
        clipPath(Path().apply { addOval(Rect(center, radius * 0.9f)) }) {
            drawCircle(Color.Black, radius * 0.9f)
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                layers.forEachIndexed { index, layer ->
                    val (ax, ay, az) = layer.axis(t)
                    native.drawLayer(
                        images[index], layer.width, layer.height, center, unit,
                        grow = layer.grow,
                        spin = mix(layer.spin.first, layer.spin.second, t),
                        tilt = layer.tilt, axis = floatArrayOf(ax, ay, az),
                        paint = layerPaint(layer.color, layer.alpha, layer.hue * sin(t * PI.toFloat() * 2)),
                    )
                }
                native.drawLayer(
                    highlight, 239f, 266f, center, unit,
                    grow = 0.6f, spin = mix(360f, 250f, t), tilt = 0f, axis = floatArrayOf(0f, 0f, 1f),
                    paint = layerPaint(null, 0.3f, 0f),
                )
            }
        }
        // Softens the sphere's edge into the page.
        drawCircle(
            Brush.radialGradient(0f to Color.Black, 0.8f to Color.Black, 1f to Color.Transparent, center = center, radius = radius),
            radius,
            blendMode = BlendMode.DstIn,
        )
    }
}

private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

/**
 * A layer's paint: `colorMultiply(color)`, `saturation(1.6)`, `opacity(alpha)`, then
 * `hueRotation(hue°)`, in SwiftUI's order, folded into one colour matrix; added as light.
 */
private fun layerPaint(color: Color?, alpha: Float, hue: Float): Paint {
    val m = ColorMatrix()
    if (color != null) {
        m.setScale(color.red, color.green, color.blue, 1f)
        m.postConcat(ColorMatrix().apply { setSaturation(1.6f) })
    }
    m.postConcat(ColorMatrix().apply { setScale(1f, 1f, 1f, alpha) })
    if (hue != 0f) m.postConcat(hueRotation(hue))
    return bitmapPaint.apply {
        colorFilter = ColorMatrixColorFilter(m)
        blendMode = android.graphics.BlendMode.PLUS
    }
}

/** SwiftUI's (and CSS's) `hue-rotate` matrix, Rec. 709 luminance kept. */
private fun hueRotation(degrees: Float): ColorMatrix {
    val a = Math.toRadians(degrees.toDouble())
    val c = cos(a).toFloat()
    val s = sin(a).toFloat()
    return ColorMatrix(
        floatArrayOf(
            0.213f + c * 0.787f - s * 0.213f, 0.715f - c * 0.715f - s * 0.715f, 0.072f - c * 0.072f + s * 0.928f, 0f, 0f,
            0.213f - c * 0.213f + s * 0.143f, 0.715f + c * 0.285f + s * 0.140f, 0.072f - c * 0.072f - s * 0.283f, 0f, 0f,
            0.213f - c * 0.213f - s * 0.787f, 0.715f - c * 0.715f + s * 0.715f, 0.072f + c * 0.928f + s * 0.072f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        ),
    )
}

private val corners = FloatArray(8)
private val projected = FloatArray(8)
private val layerMatrix = Matrix()

/**
 * Draws one layer as SwiftUI places it: its artwork at its own size in points, grown, turned by
 * `spin`, then tipped by `tilt` degrees about `axis` through its centre and projected with
 * SwiftUI's default perspective (vanishing distance the layer's larger side), then scaled by
 * `unit` about the orb's centre. The four projected corners give an exact planar homography.
 */
private fun android.graphics.Canvas.drawLayer(
    image: Bitmap,
    width: Float,
    height: Float,
    center: Offset,
    unit: Float,
    grow: Float,
    spin: Float,
    tilt: Float,
    axis: FloatArray,
    paint: Paint,
) {
    val norm = sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]).coerceAtLeast(0.0001f)
    val kx = axis[0] / norm
    val ky = axis[1] / norm
    val kz = axis[2] / norm
    val theta = Math.toRadians(tilt.toDouble())
    val ct = cos(theta).toFloat()
    val st = sin(theta).toFloat()
    val spinRad = Math.toRadians(spin.toDouble())
    val cs = cos(spinRad).toFloat()
    val ss = sin(spinRad).toFloat()
    val depth = maxOf(width, height)
    val hw = width / 2 * grow
    val hh = height / 2 * grow
    val xs = floatArrayOf(-hw, hw, hw, -hw)
    val ys = floatArrayOf(-hh, -hh, hh, hh)
    for (i in 0 until 4) {
        // Turn in the plane.
        val x0 = xs[i] * cs - ys[i] * ss
        val y0 = xs[i] * ss + ys[i] * cs
        // Tip about the axis (Rodrigues), the layer lying at z = 0.
        val dot = kx * x0 + ky * y0
        val x1 = x0 * ct + (-kz * y0) * st + kx * dot * (1 - ct)
        val y1 = y0 * ct + (kz * x0) * st + ky * dot * (1 - ct)
        val z1 = (kx * y0 - ky * x0) * st + kz * dot * (1 - ct)
        // Perspective: m34 = −1 / depth, so w = 1 − z / depth.
        val w = (1 - z1 / depth).coerceAtLeast(0.05f)
        projected[i * 2] = center.x + x1 / w * unit
        projected[i * 2 + 1] = center.y + y1 / w * unit
    }
    corners[0] = 0f; corners[1] = 0f
    corners[2] = image.width.toFloat(); corners[3] = 0f
    corners[4] = image.width.toFloat(); corners[5] = image.height.toFloat()
    corners[6] = 0f; corners[7] = image.height.toFloat()
    layerMatrix.setPolyToPoly(corners, 0, projected, 0, 4)
    drawBitmap(image, layerMatrix, paint)
}

@Preview(showBackground = true)
@Composable
private fun SiriOrbPreview() = PreviewSurface(dark = true) {
    Box(Modifier.background(Color.Black), contentAlignment = Alignment.Center) { SiriOrb(size = 240.dp) }
}
