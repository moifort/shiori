package com.polyforms.shiori.shared.components.styles

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.toSize
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/**
 * What lies behind the glass, so the glass can blur it as iOS does ("blur, never darken"): the
 * content a [backdropSource] records each frame, and where it sits on screen. Only glass drawn
 * OUTSIDE that content may read it (a floating bar beside the page it floats over); glass inside
 * it would draw the layer into itself, so the content's own glass finds no backdrop and keeps the
 * denser fill. Android 12+ (RenderEffect); older phones keep the denser fill everywhere.
 *
 * The blur is worked out once a frame for every glass together, small: the band of the page the
 * glasses float over is drawn at a quarter of its size into [blurred], blurred there, and each
 * glass draws its own part of it stretched back. A blur holds no detail to lose, and a quarter
 * of the size is a sixteenth of the pixels: one small blur where each glass had its own at full
 * size.
 */
@Stable
class Backdrop internal constructor(internal val layer: GraphicsLayer, internal val blurred: GraphicsLayer) {
    internal var origin = Offset.Zero

    /** Where each glass sits, in the root. */
    internal val spots = mutableStateListOf<BlurSpot>()

    /** The part of the page [blurred] holds, in the root; empty until a glass is laid out. */
    internal var band by mutableStateOf(Rect.Zero)

    /** The radius [blurred] was last given, so the effect is built once. */
    internal var effectRadius = 0f
}

/** The backdrop the glass below may blur; null inside the content a backdrop records. */
val LocalBackdrop = staticCompositionLocalOf<Backdrop?> { null }

/** Whether this phone can blur what lies behind: Android 12 and up. */
val canBlurBackdrop: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

/** A backdrop to record a page into, or null where the phone cannot blur. */
@Composable
fun rememberBackdrop(): Backdrop? {
    if (!canBlurBackdrop) return null
    val layer = rememberGraphicsLayer()
    val blurred = rememberGraphicsLayer()
    return remember(layer, blurred) { Backdrop(layer, blurred) }
}

/** How much smaller than the page its blurred copy is drawn. */
private const val BLUR_SCALE = 0.25f
private val blurRadius = 18.dp

/** The band's top and foot move by steps, so a glass sliding a little leaves it as it is. */
private const val BAND_STEP = 64f

/**
 * Records this content as [backdrop], drawn unchanged, for the glass that floats over it, and
 * its blurred copy under the glasses.
 */
fun Modifier.backdropSource(backdrop: Backdrop?): Modifier =
    if (backdrop == null) {
        this
    } else {
        onGloballyPositioned { backdrop.origin = it.positionInRoot() }
            .drawWithContent {
                backdrop.layer.record { this@drawWithContent.drawContent() }
                drawLayer(backdrop.layer)

                val radius = blurRadius.toPx()
                val source = Rect(backdrop.origin, size)
                var top = Float.POSITIVE_INFINITY
                var foot = Float.NEGATIVE_INFINITY
                for (spot in backdrop.spots) {
                    val rect = spot.rect
                    if (rect.isEmpty) continue
                    top = min(top, rect.top)
                    foot = max(foot, rect.bottom)
                }
                // Across the whole page, from a little over the highest glass to a little under
                // the lowest: the blur reads past the edges of what it shows.
                val band = if (top > foot) {
                    Rect.Zero
                } else {
                    Rect(
                        source.left,
                        max(source.top, floor((top - 2 * radius) / BAND_STEP) * BAND_STEP),
                        source.right,
                        min(source.bottom, ceil((foot + 2 * radius) / BAND_STEP) * BAND_STEP),
                    )
                }
                if (band != backdrop.band) backdrop.band = band
                if (band.isEmpty) return@drawWithContent
                if (backdrop.effectRadius != radius) {
                    backdrop.blurred.renderEffect = BlurEffect(radius * BLUR_SCALE, radius * BLUR_SCALE, TileMode.Clamp)
                    backdrop.effectRadius = radius
                }
                val small = IntSize(ceil(band.width * BLUR_SCALE).toInt().coerceAtLeast(1), ceil(band.height * BLUR_SCALE).toInt().coerceAtLeast(1))
                backdrop.blurred.record(size = small) {
                    scale(BLUR_SCALE, BLUR_SCALE, pivot = Offset.Zero) {
                        translate(backdrop.origin.x - band.left, backdrop.origin.y - band.top) { drawLayer(backdrop.layer) }
                    }
                }
            }
    }

/** A glass over a backdrop: where it sits, read by the backdrop to know what to blur. */
internal class BlurSpot {
    var rect by mutableStateOf(Rect.Zero)
}

/** The backdrop seen through this shape, blurred: the ground of a glass that floats over a page. */
@Composable
internal fun Modifier.backdropBlur(backdrop: Backdrop, shape: Shape): Modifier {
    val clipped = rememberGraphicsLayer()
    val spot = remember { BlurSpot() }
    DisposableEffect(backdrop, spot) {
        backdrop.spots += spot
        onDispose { backdrop.spots -= spot }
    }
    return onGloballyPositioned {
        val rect = Rect(it.positionInRoot(), it.size.toSize())
        if (rect != spot.rect) spot.rect = rect
    }
        .drawBehind {
            val band = backdrop.band
            if (band.isEmpty) return@drawBehind
            val origin = spot.rect.topLeft
            // The shared blur, stretched back to the page's size, the part under this glass.
            clipped.record {
                translate(band.left - origin.x, band.top - origin.y) {
                    scale(1 / BLUR_SCALE, 1 / BLUR_SCALE, pivot = Offset.Zero) { drawLayer(backdrop.blurred) }
                }
            }
            // The layer clips to its own outline: a blur drawn under a canvas clip bleeds past it.
            val outline = shape.createOutline(size, layoutDirection, this)
            when (outline) {
                is Outline.Rounded -> clipped.setRoundRectOutline(Offset.Zero, size, outline.roundRect.topLeftCornerRadius.x)
                is Outline.Rectangle -> clipped.setRectOutline(Offset.Zero, size)
                is Outline.Generic -> clipped.setPathOutline(outline.path)
            }
            clipped.clip = true
            val path = Path().apply { addOutline(outline) }
            clipPath(path) { drawLayer(clipped) }
        }
}
