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
