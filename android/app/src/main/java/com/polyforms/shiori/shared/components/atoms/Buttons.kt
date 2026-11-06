package com.polyforms.shiori.shared.components.atoms

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import kotlinx.coroutines.launch

/**
 * A round glass button holding one icon, as iOS 26 draws toolbar buttons: close, confirm,
 * settings. `prominent` fills it with the accent, as a confirming action is.
 */
@Composable
fun ToolbarIconButton(
    title: String,
    symbol: String,
    modifier: Modifier = Modifier,
    prominent: Boolean = false,
    destructive: Boolean = false,
    enabled: Boolean = true,
    size: Dp = 44.dp,
    onClick: () -> Unit,
) {
    val colors = Shiori.colors
    val tint = when {
        prominent -> Color.White
        destructive -> colors.red
        else -> colors.label
    }
    Box(
        modifier
            .size(size)
            .clip(CircleShape)
            .glass(CircleShape, tint = if (prominent) colors.accent else null)
            .clickable(enabled = enabled, onClick = onClick)
            .alpha(if (enabled) 1f else 0.4f),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol(symbol), title, Modifier.size(size * 0.48f), tint = tint)
    }
}

/** A toolbar button whose action is a request: a spinner until it ends. */
@Composable
fun AsyncToolbarButton(
    title: String,
    symbol: String,
    modifier: Modifier = Modifier,
    prominent: Boolean = false,
    destructive: Boolean = false,
    enabled: Boolean = true,
    action: suspend () -> Unit,
) {
    var inProgress by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    if (inProgress) {
        Box(modifier.size(44.dp).clip(CircleShape).glass(CircleShape), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
        }
    } else {
        ToolbarIconButton(title, symbol, modifier, prominent, destructive, enabled) {
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
}

/** The white glass capsule a hero's first action wears, 52 high. */
@Composable
fun HeroProminentButton(onClick: () -> Unit, modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Row(
        modifier
            .height(52.dp)
            .scale(if (pressed) 0.97f else 1f)
            .alpha(if (pressed) 0.85f else 1f)
            .clip(CircleShape)
            .glass(CircleShape, tint = Color.White)
            .clickable(interaction, null, onClick = onClick)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CompositionLocalProvider(LocalContentColor provides Color.Black) { content() }
    }
}
