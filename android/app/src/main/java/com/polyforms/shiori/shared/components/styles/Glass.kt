package com.polyforms.shiori.shared.components.styles

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.SystemTint

/**
 * Liquid Glass and the materials, as near as Compose draws them: what lies behind, blurred, under
 * a light veil and a fine rim, as iOS draws it ("blur, never darken"). The blur needs a
 * [LocalBackdrop] (a floating bar over its page, Android 12+); without one the veil is denser,
 * since nothing blurs what shows through.
 */
@Composable
fun Modifier.glass(shape: Shape = CircleShape, tint: Color? = null, interactive: Boolean = true): Modifier {
    val colors = Shiori.colors
    val backdrop = LocalBackdrop.current
    val blurs = backdrop != null && tint == null
    val fill = tint?.copy(alpha = 0.92f)
        ?: when {
            blurs && colors.isDark -> Color(0x802C2C2E)
            blurs -> Color(0xA6FFFFFF)
            colors.isDark -> Color(0xCC2C2C2E)
            else -> Color(0xE6FFFFFF)
        }
    val rim = if (colors.isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.06f)
    val ground = if (blurs) this.backdropBlur(backdrop!!, shape) else this
    return ground.background(fill, shape).border(0.5.dp, rim, shape)
}

/** `.ultraThinMaterial` in the dark scheme, over a cover: a dark veil. */
fun Modifier.ultraThinDark(shape: Shape = RoundedCornerShape(3.dp)): Modifier =
    background(Color.Black.copy(alpha = 0.35f), shape)

/** `.ultraThinMaterial` over a page. */
@Composable
fun Modifier.ultraThinMaterial(shape: Shape = RoundedCornerShape(0.dp)): Modifier {
    val dark = Shiori.colors.isDark
    return background(if (dark) Color(0xB31C1C1E) else Color(0xB3F7F7F7), shape)
}

/** A grouped card: the white rounded block of an inset grouped list. */
@Composable
fun Modifier.card(radius: Dp = 22.dp): Modifier =
    background(Shiori.colors.secondaryGroupedBackground, RoundedCornerShape(radius))

/** The colour an iOS system tint names, in the current scheme. */
@Composable
fun SystemTint.color(): Color {
    val c = Shiori.colors
    return when (this) {
        SystemTint.BLUE -> c.blue
        SystemTint.GREEN -> c.green
        SystemTint.RED -> c.red
        SystemTint.ORANGE -> c.orange
        SystemTint.YELLOW -> c.yellow
        SystemTint.PINK -> c.pink
        SystemTint.PURPLE -> c.purple
        SystemTint.INDIGO -> c.indigo
        SystemTint.TEAL -> c.teal
        SystemTint.CYAN -> c.cyan
        SystemTint.MINT -> c.mint
        SystemTint.BROWN -> c.brown
        SystemTint.GRAY -> c.gray
    }
}

/** Audible's orange, for its own buttons and marks. */
val AudibleOrange = Color(0xFFF8991C)

/** The AI shimmer's colours: blue, purple, pink, orange. */
@Composable
fun aiGlowColors(): List<Color> = with(Shiori.colors) { listOf(blue, purple, pink, orange) }

/**
 * Draws the content at `amount` of its colour: 1 as it is, 0 in black and white, as a book turned
 * down or a saga set aside. Animate the amount for the slow drain (`setAsideAnimation`).
 */
fun Modifier.saturation(amount: Float): Modifier =
    if (amount >= 1f) {
        this
    } else {
        drawWithContent {
            val paint = androidx.compose.ui.graphics.Paint().apply {
                colorFilter = androidx.compose.ui.graphics.ColorFilter.colorMatrix(
                    androidx.compose.ui.graphics.ColorMatrix().apply { setToSaturation(amount.coerceIn(0f, 1f)) },
                )
            }
            drawIntoCanvas { canvas ->
                canvas.saveLayer(androidx.compose.ui.geometry.Rect(androidx.compose.ui.geometry.Offset.Zero, size), paint)
                drawContent()
                canvas.restore()
            }
        }
    }
