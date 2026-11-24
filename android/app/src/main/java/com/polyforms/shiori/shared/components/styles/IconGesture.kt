package com.polyforms.shiori.shared.components.styles

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * The gesture an action button's icon makes once its state changed: it does what it says, once,
 * in 0.3 to 0.4 s, never in a loop. Only buttons that change a state have one; a button that
 * opens a screen or a menu keeps the press alone. With animations off none plays.
 */
enum class IconGesture {
    /** A bell rung: it swings left, then right, from its top. */
    SWING,

    /** An eye closing: the lid comes down, then lifts. */
    BLINK,

    /** A bookmark slipped into the book: it slides down, then back. */
    SLIP,

    /** Binoculars scanning the horizon: one sweep, left to right. */
    SWEEP,

    /** A star or a check that has just been given: a small hop up. */
    HOP,

    /** A heart: two beats. */
    BEAT,

    /** A moon falling asleep: a slow rock. */
    ROCK,
}

/** Plays `gesture` each time `trigger` changes after the first composition; null bounces. */
@Composable
fun Modifier.iconGesture(gesture: IconGesture?, trigger: Any?): Modifier {
    val angle = remember { Animatable(0f) }
    val lid = remember { Animatable(1f) }
    val scale = remember { Animatable(1f) }
    val x = remember { Animatable(0f) }
    val y = remember { Animatable(0f) }
    val still = reduceMotion()
    val density = LocalDensity.current.density
    val first = remember { mutableIntStateOf(0) }
    LaunchedEffect(trigger) {
        if (first.intValue++ == 0 || still) return@LaunchedEffect
        coroutineScope {
            when (gesture) {
                IconGesture.SWING -> launch { angle.animateTo(0f, keyframes { durationMillis = 380; -16f at 100; 16f at 220; -6f at 300 }) }
                IconGesture.ROCK -> launch { angle.animateTo(0f, keyframes { durationMillis = 420; -14f at 180; 8f at 320 }) }
                IconGesture.SWEEP -> {
                    launch { angle.animateTo(0f, keyframes { durationMillis = 380; -8f at 120; 8f at 280 }) }
                    launch { x.animateTo(0f, keyframes { durationMillis = 380; -4f at 120; 4f at 280 }) }
                }
                IconGesture.BLINK -> launch { lid.animateTo(1f, keyframes { durationMillis = 320; 0.1f at 120; 0.1f at 180 }) }
                IconGesture.BEAT -> launch { scale.animateTo(1f, keyframes { durationMillis = 400; 1.22f at 100; 1f at 200; 1.16f at 300 }) }
                IconGesture.SLIP -> launch {
                    y.animateTo(5f, keyframes { durationMillis = 140 })
                    y.animateTo(0f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium))
                }
                IconGesture.HOP -> launch {
                    y.animateTo(-6f, keyframes { durationMillis = 140 })
                    y.animateTo(0f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium))
                }
                // No gesture of its own: a bounce, as SwiftUI's `.bounce` symbol effect.
                null -> launch { scale.animateTo(1f, keyframes { durationMillis = 300; 0.8f at 100; 1.12f at 200 }) }
            }
        }
    }
    return graphicsLayer {
        transformOrigin = if (gesture == IconGesture.SWING) TransformOrigin(0.5f, 0f) else TransformOrigin.Center
        rotationZ = angle.value
        scaleX = scale.value
        scaleY = scale.value * lid.value
        translationX = x.value * density
        translationY = y.value * density
    }
}

@Preview(showBackground = true)
@Composable
private fun IconGesturePreview() = PreviewSurface {
    var turns by remember { mutableIntStateOf(0) }
    Row(Modifier.padding(20.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        listOf("bell" to IconGesture.SWING, "eye" to IconGesture.BLINK, "bookmark" to IconGesture.SLIP, "binoculars" to IconGesture.SWEEP, "checkmark" to IconGesture.HOP, "heart" to IconGesture.BEAT, "moon" to IconGesture.ROCK).forEach { (symbol, gesture) ->
            Icon(Symbol(symbol), null, Modifier.size(28.dp).iconGesture(gesture, turns).plainClickable { turns += 1 })
        }
    }
}
