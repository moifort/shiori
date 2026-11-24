package com.polyforms.shiori.shared.components.styles

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.size
import com.polyforms.shiori.PreviewSurface

/*
 * Every round or capsule action button of the app: white for the action that leads a screen,
 * glass beside it, a circle when the icon says it all. One style, so every button answers a
 * touch the same way:
 *
 * - pressed, it sinks to 0.92 (0.96 when it spans the screen) and dims a little, following the
 *   finger: slid off, it lets go without acting;
 * - let go, it springs back with a slight bounce.
 *
 * Monochrome throughout: white, glass and black. What a tap did is said by the fill
 * (glass ↔ white), the symbol (filled or slashed) and the gesture (`AsyncActionButton`'s
 * outcome, `ActionToggle`), never by a colour. With animations turned off it only dims.
 *
 * The size follows the control size: small 28, regular 36, large 50; `height` overrides it.
 */

/** White, black text: the action still to do. Glass, white text: beside it, or the action done. */
enum class ActionFill { WHITE, GLASS }

enum class ActionShape { CAPSULE, CIRCLE }

/** The control sizes of SwiftUI, as the action buttons read them. */
enum class ActionSize(val side: Dp) { MINI(24.dp), SMALL(28.dp), REGULAR(36.dp), LARGE(50.dp), EXTRA_LARGE(56.dp) }

/** The shape a group of action buttons takes over their own: a hero whose buttons lose their words turns them round. */
val LocalActionShape = compositionLocalOf<ActionShape?> { null }

/** Whether the system's animations are off ("Remove animations"), as iOS's Reduce Motion. */
@Composable
fun reduceMotion(): Boolean {
    val context = LocalContext.current
    return remember(context) {
        android.provider.Settings.Global.getFloat(context.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}

/**
 * The press every action button shares: sunk to `depth` and dimmed while held, sprung back with
 * a slight bounce once let go. With animations off, dimmed only.
 */
@Composable
fun Modifier.pressEffect(isPressed: Boolean, depth: Float = 0.92f): Modifier {
    val still = reduceMotion()
    val scale by animateFloatAsState(
        if (isPressed && !still) depth else 1f,
        if (still) tween(150) else spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow),
        label = "press",
    )
    val alpha by animateFloatAsState(if (isPressed) 0.85f else 1f, tween(150), label = "pressAlpha")
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
        this.alpha = alpha
    }
}

/** Solid white, or glass: the fill an action button stands on. */
@Composable
fun Modifier.actionFill(fill: ActionFill, shape: androidx.compose.ui.graphics.Shape, isRaised: Boolean = false): Modifier = when (fill) {
    ActionFill.WHITE -> this
        .then(if (isRaised) Modifier.shadow(11.dp, shape, ambientColor = Color.Black.copy(alpha = 0.45f), spotColor = Color.Black.copy(alpha = 0.45f)) else Modifier)
        .clip(shape)
        .background(Color.White, shape)
    ActionFill.GLASS -> this.clip(shape).glassOnDark(shape)
}

/** Glass over a page or a cover, whose label is white: the dark glass, in both schemes. */
@Composable
fun Modifier.glassOnDark(shape: androidx.compose.ui.graphics.Shape = CircleShape): Modifier =
    background(Color.White.copy(alpha = 0.2f), shape).border(0.5.dp, Color.White.copy(alpha = 0.25f), shape)

/**
 * An action button: `content` is its label, drawn in black on white or white on glass. The press
 * follows the finger and acts only when let go on the button.
 */
@Composable
fun ActionButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    fill: ActionFill = ActionFill.WHITE,
    shape: ActionShape = ActionShape.CAPSULE,
    size: ActionSize = ActionSize.REGULAR,
    height: Dp? = null,
    spansWidth: Boolean = false,
    isRaised: Boolean = false,
    isBare: Boolean = false,
    enabled: Boolean = true,
    /** Takes no tap but keeps its full colour: nothing is disabled, there is just nothing to do. */
    inert: Boolean = false,
    contentDescription: String? = null,
    content: @Composable RowScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val side = height ?: size.side
    val drawn = LocalActionShape.current ?: shape
    val outline = CircleShape
    val padding = when {
        side < 26.dp -> 8.dp
        side < 32.dp -> 10.dp
        side < 46.dp -> 12.dp
        else -> 20.dp
    }
    val foreground = if (fill == ActionFill.WHITE) Color.Black else Color.White
    Row(
        modifier
            .pressEffect(pressed && enabled, if (spansWidth) 0.96f else 0.92f)
            .graphicsLayer { alpha = if (enabled) 1f else 0.45f }
            .then(
                when {
                    isBare -> Modifier
                    drawn == ActionShape.CIRCLE -> Modifier.defaultMinSize(side, side)
                    else -> Modifier.defaultMinSize(minHeight = side)
                },
            )
            .actionFill(fill, outline, isRaised)
            .clickable(interaction, null, enabled = enabled && !inert, role = androidx.compose.ui.semantics.Role.Button, onClickLabel = contentDescription, onClick = onClick)
            .then(if (isBare || drawn == ActionShape.CIRCLE) Modifier else Modifier.padding(horizontal = padding)),
        horizontalArrangement = Arrangement.spacedBy(if (side >= 46.dp) 8.dp else 5.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CompositionLocalProvider(LocalContentColor provides foreground) { content() }
    }
}

/** The font an action button's label takes at its height: headline at 50, caption above 28. */
@Composable
fun actionLabelStyle(side: Dp) = when {
    side >= 46.dp -> Shiori.type.headline
    side >= 34.dp -> Shiori.type.subheadline.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
    else -> Shiori.type.caption.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
}

/** The common label: a symbol and a word, in the button's colour. */
@Composable
fun ActionLabel(title: String, symbol: String?, side: Dp = ActionSize.REGULAR.side, iconOnly: Boolean = false) {
    val style = actionLabelStyle(side)
    if (symbol != null) Icon(Symbol(symbol), if (iconOnly) title else null, Modifier.size(if (side >= 46.dp) 20.dp else if (side >= 34.dp) 17.dp else 14.dp), tint = LocalContentColor.current)
    if (!iconOnly) Text(title, style = style, color = LocalContentColor.current, maxLines = 1)
}

@Preview(showBackground = true)
@Composable
private fun ActionButtonStylePreview() = PreviewSurface(dark = true) {
    Column(Modifier.background(Color.Black).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ActionButton({}) { ActionLabel("Ajouter", "plus") }
            ActionButton({}, fill = ActionFill.GLASS) { ActionLabel("Envies", "heart") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ActionButton({}, fill = ActionFill.GLASS, shape = ActionShape.CIRCLE) { ActionLabel("Pas intéressé", "eye.slash", iconOnly = true) }
            ActionButton({}, shape = ActionShape.CIRCLE) { ActionLabel("Déjà lu", "checkmark", iconOnly = true) }
            ActionButton({}, enabled = false) { ActionLabel("Ajouter", "plus") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            ActionButton({}, fill = ActionFill.GLASS, size = ActionSize.SMALL) { ActionLabel("Small", null, ActionSize.SMALL.side) }
            ActionButton({}, fill = ActionFill.GLASS) { ActionLabel("Regular", null) }
            ActionButton({}, fill = ActionFill.GLASS, size = ActionSize.LARGE) { ActionLabel("Large", null, ActionSize.LARGE.side) }
        }
        Box(Modifier.fillMaxWidth()) {
            ActionButton({}, Modifier.fillMaxWidth(), size = ActionSize.LARGE, spansWidth = true) { ActionLabel("Continuer", null, ActionSize.LARGE.side) }
        }
    }
}
