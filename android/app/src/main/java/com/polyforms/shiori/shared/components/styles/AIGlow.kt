package com.polyforms.shiori.shared.components.styles

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp

/**
 * What every AI effect of the app shares on Android: a clock that only ever invalidates drawing,
 * and the translation of SwiftUI's blur radii into Android's.
 */
object AIGlow {
    /** `RenderEffect` blur and colour filters on a layer exist from Android 12. */
    val canBlur: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    /**
     * SwiftUI's `.blur(radius:)` and `.shadow(radius:)` take the Gaussian's deviation; Android's
     * `RenderEffect.createBlurEffect` takes a radius it turns into one as `0.57735 r + 0.5`. This
     * gives the Android radius, in pixels, for a SwiftUI radius in points.
     */
    fun blurRadius(points: Dp, density: Density): Float {
        val sigma = with(density) { points.toPx() }
        return ((sigma - 0.5f) / 0.57735f).coerceAtLeast(0.01f)
    }
}

/**
 * Seconds since the effect appeared, advanced every frame. Read it only while drawing (in a draw
 * or `graphicsLayer` block): the page around never recomposes for it. Holds at `0` with
 * animations off.
 */
@Composable
fun rememberEffectClock(): State<Float> {
    val still = reduceMotion()
    val seconds = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(still) {
        if (still) return@LaunchedEffect
        val start = withFrameNanos { it } - (seconds.floatValue * 1e9f).toLong()
        while (true) withFrameNanos { seconds.floatValue = (it - start) / 1e9f }
    }
    return seconds
}
