package com.polyforms.shiori.shared.components.atoms

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.RowScope
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.mutableIntStateOf
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.ActionOutcome
import com.polyforms.shiori.shared.components.styles.ActionShape
import com.polyforms.shiori.shared.components.styles.ActionSize
import com.polyforms.shiori.shared.components.styles.SuccessTap
import com.polyforms.shiori.shared.components.styles.refusalShake
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import androidx.compose.material3.Text

/**
 * A button whose action is a request: it shows a spinner in place of its label until the
 * request ends, and ignores taps meanwhile. `content` receives the tap and draws the button.
 */
@Composable
fun AsyncAction(
    action: suspend () -> Unit,
    content: @Composable (onClick: () -> Unit, inProgress: Boolean, label: @Composable (@Composable () -> Unit) -> Unit) -> Unit,
) {
    var inProgress by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val onClick: () -> Unit = {
        if (!inProgress) {
            inProgress = true
            scope.launch {
                try {
                    action()
                } finally {
                    inProgress = false
                }
            }
        }
    }
    content(onClick, inProgress) { inner ->
        Box(contentAlignment = Alignment.Center) {
            Box(Modifier.alpha(if (inProgress) 0f else 1f)) { inner() }
            if (inProgress) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
        }
    }
}

/**
 * An action button whose call takes time on the network: a spinner in place of its label from the
 * tap until the call settles, a second tap refused meanwhile, the label keeping its width. A call
 * that says how it went is answered too: a success tap once done, the caller's own state taking
 * over from there; a shake and an error tap once refused, the label back as it was.
 */
@Composable
fun AsyncActionButton(
    outcome: suspend () -> ActionOutcome?,
    modifier: Modifier = Modifier,
    fill: ActionFill = ActionFill.WHITE,
    shape: ActionShape = ActionShape.CAPSULE,
    size: ActionSize = ActionSize.REGULAR,
    height: androidx.compose.ui.unit.Dp? = null,
    spansWidth: Boolean = false,
    enabled: Boolean = true,
    contentDescription: String? = null,
    content: @Composable RowScope.() -> Unit,
) {
    var inProgress by remember { mutableStateOf(false) }
    var successes by remember { mutableIntStateOf(0) }
    var refusals by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    SuccessTap(successes)
    ActionButton(
        onClick = {
            if (!inProgress) {
                inProgress = true
                scope.launch {
                    val result = try {
                        outcome()
                    } finally {
                        inProgress = false
                    }
                    when (result) {
                        ActionOutcome.DONE -> successes += 1
                        ActionOutcome.REFUSED -> refusals += 1
                        null -> Unit
                    }
                }
            }
        },
        modifier = modifier.refusalShake(refusals),
        fill = fill,
        shape = shape,
        size = size,
        height = height,
        spansWidth = spansWidth,
        enabled = enabled && !inProgress,
        contentDescription = contentDescription,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Row(Modifier.alpha(if (inProgress) 0f else 1f), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) { content() }
            if (inProgress) CircularProgressIndicator(Modifier.size(18.dp), color = LocalContentColor.current, strokeWidth = 2.dp)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun AsyncActionButtonPreview() = PreviewSurface(dark = true) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        AsyncActionButton({ kotlinx.coroutines.delay(2000); null }) { ActionLabel(L("Synchroniser"), "arrow.triangle.2.circlepath") }
        AsyncActionButton({ kotlinx.coroutines.delay(1000); ActionOutcome.REFUSED }, fill = ActionFill.GLASS) { ActionLabel(L("Ajouter"), "plus") }
    }
}

@Preview(showBackground = true)
@Composable
private fun AsyncActionPreview() = PreviewSurface {
    AsyncAction(action = {}) { onClick, _, label ->
        androidx.compose.material3.TextButton(onClick = onClick) { label { Text("Envoyer") } }
    }
}
