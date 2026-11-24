package com.polyforms.shiori.shared.components.styles

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.unit.dp

/**
 * What lies behind the glass, so the glass can blur it as iOS does ("blur, never darken"): the
 * content a [backdropSource] records each frame, and where it sits on screen. Only glass drawn
 * OUTSIDE that content may read it (a floating bar beside the page it floats over); glass inside
 * it would draw the layer into itself, so the content's own glass finds no backdrop and keeps the
 * denser fill. Android 12+ (RenderEffect); older phones keep the denser fill everywhere.
 */
@Stable
class Backdrop internal constructor(internal val layer: GraphicsLayer) {
    internal var origin = Offset.Zero
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
    return remember(layer) { Backdrop(layer) }
}

/** Records this content as [backdrop], drawn unchanged, for the glass that floats over it. */
fun Modifier.backdropSource(backdrop: Backdrop?): Modifier =
    if (backdrop == null) {
        this
    } else {
        onGloballyPositioned { backdrop.origin = it.positionInRoot() }
            .drawWithContent {
                backdrop.layer.record { this@drawWithContent.drawContent() }
                drawLayer(backdrop.layer)
            }
    }

private class BlurSpot {
    var origin = Offset.Zero
}

/** The backdrop seen through this shape, blurred: the ground of a glass that floats over a page. */
@Composable
internal fun Modifier.backdropBlur(backdrop: Backdrop, shape: Shape): Modifier {
    val blurred = rememberGraphicsLayer()
    val spot = remember { BlurSpot() }
    return onGloballyPositioned { spot.origin = it.positionInRoot() }
        .drawBehind {
            val radius = 18.dp.toPx()
            blurred.renderEffect = BlurEffect(radius, radius, TileMode.Clamp)
            blurred.record {
                translate(backdrop.origin.x - spot.origin.x, backdrop.origin.y - spot.origin.y) {
                    drawLayer(backdrop.layer)
                }
            }
            // The layer clips to its own outline: a blur drawn under a canvas clip bleeds past it.
            val outline = shape.createOutline(size, layoutDirection, this)
            when (outline) {
                is Outline.Rounded -> blurred.setRoundRectOutline(Offset.Zero, size, outline.roundRect.topLeftCornerRadius.x)
                is Outline.Rectangle -> blurred.setRectOutline(Offset.Zero, size)
                is Outline.Generic -> blurred.setPathOutline(outline.path)
            }
            blurred.clip = true
            val path = Path().apply { addOutline(outline) }
            clipPath(path) { drawLayer(blurred) }
        }
}
