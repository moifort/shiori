package com.polyforms.shiori.shared.components.styles

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Column
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** How a button is drawn, as SwiftUI's `.borderedProminent`, `.bordered` and `.plain`. */
enum class ButtonKind { PROMINENT, BORDERED, PLAIN }

/**
 * An iOS button: a capsule filled with the accent (`PROMINENT`), tinted (`BORDERED`), or bare
 * text in the accent (`PLAIN`). An `async` action shows a spinner until it ends.
 */
@Composable
fun ShioriButton(
    title: String,
    modifier: Modifier = Modifier,
    symbol: String? = null,
    kind: ButtonKind = ButtonKind.PROMINENT,
    tint: Color = Shiori.colors.accent,
    destructive: Boolean = false,
    enabled: Boolean = true,
    large: Boolean = false,
    fillWidth: Boolean = false,
    foreground: Color? = null,
    action: suspend () -> Unit,
) {
    var inProgress by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    val base = if (destructive) colors.red else tint
    val (background, shown) = when (kind) {
        ButtonKind.PROMINENT -> base to Color.White
        ButtonKind.BORDERED -> base.copy(alpha = 0.15f) to base
        ButtonKind.PLAIN -> Color.Transparent to base
    }
    val foreground = foreground ?: shown
    Row(
        modifier
            .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
            .height(if (large) 50.dp else 36.dp)
            .clip(CircleShape)
            .background(background)
            .clickable(enabled = enabled && !inProgress) {
                inProgress = true
                scope.launch {
                    try {
                        action()
                    } finally {
                        inProgress = false
                    }
                }
            }
            .alpha(if (enabled) 1f else 0.4f)
            .padding(horizontal = if (kind == ButtonKind.PLAIN) 4.dp else 16.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (inProgress) {
            CircularProgressIndicator(Modifier.size(18.dp), color = foreground, strokeWidth = 2.dp)
        } else {
            if (symbol != null) Icon(Symbol(symbol), null, Modifier.size(18.dp), tint = foreground)
            Text(
                title,
                style = (if (large) Shiori.type.headline else Shiori.type.subheadline).copy(fontWeight = FontWeight.SemiBold),
                color = foreground,
                maxLines = 1,
            )
        }
    }
}

/** A tappable row with no ripple, as a SwiftUI `.plain` button. */
fun Modifier.plainClickable(enabled: Boolean = true, onClick: () -> Unit): Modifier =
    this.then(
        Modifier.clickable(
            interactionSource = MutableInteractionSource(),
            indication = null,
            enabled = enabled,
            onClick = onClick,
        ),
    )

/** The segmented control: a grey track, the chosen segment raised in white. */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selection: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    height: Dp = 32.dp,
) {
    val colors = Shiori.colors
    BoxWithConstraints(
        modifier
            .height(height)
            .clip(RoundedCornerShape(9.dp))
            .background(colors.tertiaryFill)
            .padding(2.dp),
    ) {
        val segment = maxWidth / options.size.coerceAtLeast(1)
        val index = options.indexOf(selection).coerceAtLeast(0)
        val offset by animateDpAsState(segment * index, label = "segment")
        Box(
            Modifier
                .offset(x = offset)
                .width(segment)
                .fillMaxHeight()
                .shadow(1.dp, RoundedCornerShape(7.dp))
                .background(if (colors.isDark) Color(0xFF636366) else Color.White, RoundedCornerShape(7.dp)),
        )
        Row(Modifier.fillMaxWidth().fillMaxHeight()) {
            options.forEach { option ->
                Box(
                    Modifier.weight(1f).fillMaxHeight().plainClickable { onSelect(option) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label(option),
                        style = Shiori.type.footnote.copy(
                            fontWeight = if (option == selection) FontWeight.SemiBold else FontWeight.Medium,
                        ),
                        color = colors.label,
                        maxLines = 1,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

@Composable
fun ShioriDivider(modifier: Modifier = Modifier) = HorizontalDivider(modifier, thickness = 0.5.dp, color = Shiori.colors.separator)

@Composable
fun ShioriVerticalDivider(modifier: Modifier = Modifier) =
    VerticalDivider(modifier, thickness = 0.5.dp, color = Shiori.colors.separator)

/** Content drawn in a colour, as `.foregroundStyle`. */
@Composable
fun Tinted(color: Color, content: @Composable () -> Unit) =
    CompositionLocalProvider(LocalContentColor provides color, content = content)

/** A row of the inset grouped list: padded, at least 44 high. */
@Composable
fun GroupedRow(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable RowScope.() -> Unit) {
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Preview(showBackground = true)
@Composable
private fun ControlsPreview() = PreviewSurface {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ShioriButton("Ajouter", symbol = "plus") {}
        ShioriButton("Plus tard", kind = ButtonKind.BORDERED) {}
        ShioriButton("Supprimer", destructive = true, kind = ButtonKind.PLAIN) {}
        ShioriDivider()
        GroupedRow(onClick = {}) { Text("Une ligne de réglage") }
        Tinted(Shiori.colors.red) { Text("Teinté") }
    }
}
