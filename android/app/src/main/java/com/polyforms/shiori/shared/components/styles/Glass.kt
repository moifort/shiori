package com.polyforms.shiori.shared.components.styles

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.SystemTint

/**
 * Liquid Glass and the materials, as near as Compose draws them: a translucent fill with a fine
 * rim. iOS blurs what lies behind; Android has no backdrop blur, so the fill is denser.
 */
@Composable
fun Modifier.glass(shape: Shape = CircleShape, tint: Color? = null, interactive: Boolean = true): Modifier {
    val colors = Shiori.colors
    val fill = tint?.copy(alpha = 0.92f)
        ?: if (colors.isDark) Color(0xCC2C2C2E) else Color(0xE6FFFFFF)
    val rim = if (colors.isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.06f)
    return this.background(fill, shape).border(0.5.dp, rim, shape)
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
