package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionShape
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.iconGesture
import com.polyforms.shiori.shared.components.styles.refusalShake
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * A round button that stands for a state the reader turns on and off: the alerts of a series or
 * an edition, a book seen or set aside. It shows the state, never the action: on, its symbol in
 * black on white; off, the same symbol slashed, in white on glass. TalkBack says what a tap does.
 *
 * The tap answers at once, before the server: the caller turns the state over as soon as asked,
 * the symbol is replaced in place, and the phone taps back, firmer on than off. Should the state
 * fall back once the call settled, the server refused: the button shakes with an error tap.
 */
@Composable
fun ActionToggle(
    isOn: Boolean,
    symbol: String,
    turnOnLabel: String,
    turnOffLabel: String,
    modifier: Modifier = Modifier,
    offSymbol: String? = null,
    size: Dp = 50.dp,
    gesture: IconGesture? = null,
    /** Asked before turning the state off; null turns it off at once. Turning it on never asks. */
    turnOffConfirmation: String? = null,
    onToggle: suspend (Boolean) -> Unit,
) {
    val latest by rememberUpdatedState(isOn)
    var refusals by remember { mutableIntStateOf(0) }
    var turns by remember { mutableIntStateOf(0) }
    var confirmsTurnOff by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val first = remember { mutableStateOf(true) }
    LaunchedEffect(isOn) {
        if (first.value) first.value = false
        else haptics.performHapticFeedback(if (isOn) HapticFeedbackType.Confirm else HapticFeedbackType.ContextClick)
    }

    fun turnOver() {
        val wanted = !isOn
        turns += 1
        scope.launch {
            onToggle(wanted)
            // The caller turned the state over at once; back where it was once the call
            // settled, the server said no.
            delay(50)
            if (latest != wanted) refusals += 1
        }
    }

    ActionButton(
        onClick = { if (isOn && turnOffConfirmation != null) confirmsTurnOff = true else turnOver() },
        modifier = modifier.refusalShake(refusals).semantics { contentDescription = if (isOn) turnOffLabel else turnOnLabel },
        fill = if (isOn) ActionFill.WHITE else ActionFill.GLASS,
        shape = ActionShape.CIRCLE,
        height = size,
    ) {
        AnimatedContent(isOn, transitionSpec = { (scaleIn(initialScale = 0.6f) + fadeIn()) togetherWith (scaleOut(targetScale = 0.6f) + fadeOut()) }, label = "toggle") { on ->
            Icon(
                Symbol(if (on) symbol else offSymbol ?: "$symbol.slash"),
                null,
                Modifier.size(if (size >= 44.dp) 22.dp else 15.dp).iconGesture(gesture, turns),
                tint = if (on) Color.Black else Color.White,
            )
        }
    }
    if (confirmsTurnOff && turnOffConfirmation != null) {
        ConfirmationSheet(turnOffConfirmation, listOf(ConfirmationChoice(turnOffLabel, destructive = true) { turnOver() })) { confirmsTurnOff = false }
    }
}

@Preview(showBackground = true)
@Composable
private fun ActionTogglePreview() = PreviewSurface(dark = true) {
    var on by remember { mutableStateOf(false) }
    Row(Modifier.background(Color(0xFF3F51B5)).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        ActionToggle(on, "bell", L("Suivre"), L("Ne plus suivre"), gesture = IconGesture.SWING, turnOffConfirmation = L("Ne plus suivre la série ?")) { on = it }
        ActionToggle(true, "eye", L("Marquer comme vu"), L("Marquer comme non vu")) {}
        ActionToggle(false, "eye", L("Marquer comme vu"), L("Marquer comme non vu")) {}
    }
}
