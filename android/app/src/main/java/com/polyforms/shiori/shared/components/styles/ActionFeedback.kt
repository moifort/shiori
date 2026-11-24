package com.polyforms.shiori.shared.components.styles

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.keyframes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface

/*
 * What an action button says once its call settled: the phone taps back on success, and on a
 * refusal the button shakes briefly where it stands (three short swings, 0.3 s) with an error
 * tap, then shows its state from before. Monochrome, no toast: the screen's own error message,
 * if it has one, says the rest. With animations off it does not shake; the taps remain.
 */

/** The outcome of a call an action button waited on. */
enum class ActionOutcome {
    DONE, REFUSED;

    companion object {
        fun of(accepted: Boolean) = if (accepted) DONE else REFUSED
    }
}

/** Shakes the view and taps an error each time `trigger` grows past zero. */
@Composable
fun Modifier.refusalShake(trigger: Int): Modifier {
    val offset = remember { Animatable(0f) }
    val haptics = LocalHapticFeedback.current
    val still = reduceMotion()
    val density = LocalDensity.current.density
    LaunchedEffect(trigger) {
        if (trigger == 0) return@LaunchedEffect
        haptics.performHapticFeedback(HapticFeedbackType.Reject)
        if (still) return@LaunchedEffect
        offset.animateTo(0f, keyframes {
            durationMillis = 300
            -6f at 50
            6f at 100
            -4f at 150
            4f at 200
            -2f at 250
        })
    }
    return graphicsLayer { translationX = offset.value * density }
}

/** Taps a success each time `trigger` grows past zero. */
@Composable
fun SuccessTap(trigger: Int) {
    val haptics = LocalHapticFeedback.current
    LaunchedEffect(trigger) { if (trigger > 0) haptics.performHapticFeedback(HapticFeedbackType.Confirm) }
}

@Preview(showBackground = true)
@Composable
private fun ActionFeedbackPreview() = PreviewSurface(dark = true) {
    var refusals by remember { mutableIntStateOf(0) }
    Row(Modifier.padding(20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ActionButton({ refusals += 1 }, Modifier.refusalShake(refusals), fill = ActionFill.GLASS) { ActionLabel("Ajouter", "plus") }
    }
}
