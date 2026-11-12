package com.polyforms.shiori.shared.components.styles

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface

/**
 * The iOS system palette the app is drawn in: Shiori uses Apple's semantic colours and
 * nothing of its own, so Android reproduces them, light and dark, value for value.
 */
@Immutable
data class ShioriColors(
    val isDark: Boolean,
    val background: Color,
    val groupedBackground: Color,
    val secondaryGroupedBackground: Color,
    val tertiaryGroupedBackground: Color,
    val label: Color,
    val secondaryLabel: Color,
    val tertiaryLabel: Color,
    val quaternaryLabel: Color,
    val separator: Color,
    val fill: Color,
    val secondaryFill: Color,
    val tertiaryFill: Color,
    val accent: Color,
    val blue: Color,
    val green: Color,
    val red: Color,
    val orange: Color,
    val yellow: Color,
    val pink: Color,
    val purple: Color,
    val indigo: Color,
    val teal: Color,
    val cyan: Color,
    val mint: Color,
    val brown: Color,
    val gray: Color,
)

val LightColors = ShioriColors(
    isDark = false,
    background = Color(0xFFFFFFFF),
    groupedBackground = Color(0xFFF2F2F7),
    secondaryGroupedBackground = Color(0xFFFFFFFF),
    tertiaryGroupedBackground = Color(0xFFF2F2F7),
    label = Color(0xFF000000),
    secondaryLabel = Color(0x993C3C43),
    tertiaryLabel = Color(0x4D3C3C43),
    quaternaryLabel = Color(0x2E3C3C43),
    separator = Color(0x4A3C3C43),
    fill = Color(0x33787880),
    secondaryFill = Color(0x29787880),
    tertiaryFill = Color(0x1F767680),
    accent = Color(0xFF007AFF),
    blue = Color(0xFF007AFF),
    green = Color(0xFF34C759),
    red = Color(0xFFFF3B30),
    orange = Color(0xFFFF9500),
    yellow = Color(0xFFFFCC00),
    pink = Color(0xFFFF2D55),
    purple = Color(0xFFAF52DE),
    indigo = Color(0xFF5856D6),
    teal = Color(0xFF30B0C7),
    cyan = Color(0xFF32ADE6),
    mint = Color(0xFF00C7BE),
    brown = Color(0xFFA2845E),
    gray = Color(0xFF8E8E93),
)

val DarkColors = ShioriColors(
    isDark = true,
    background = Color(0xFF000000),
    groupedBackground = Color(0xFF000000),
    secondaryGroupedBackground = Color(0xFF1C1C1E),
    tertiaryGroupedBackground = Color(0xFF2C2C2E),
    label = Color(0xFFFFFFFF),
    secondaryLabel = Color(0x99EBEBF5),
    tertiaryLabel = Color(0x4DEBEBF5),
    quaternaryLabel = Color(0x29EBEBF5),
    separator = Color(0x99545458),
    fill = Color(0x5C787880),
    secondaryFill = Color(0x52787880),
    tertiaryFill = Color(0x3D767680),
    accent = Color(0xFF0A84FF),
    blue = Color(0xFF0A84FF),
    green = Color(0xFF30D158),
    red = Color(0xFFFF453A),
    orange = Color(0xFFFF9F0A),
    yellow = Color(0xFFFFD60A),
    pink = Color(0xFFFF375F),
    purple = Color(0xFFBF5AF2),
    indigo = Color(0xFF5E5CE6),
    teal = Color(0xFF40C8E0),
    cyan = Color(0xFF64D2FF),
    mint = Color(0xFF63E6E2),
    brown = Color(0xFFAC8E68),
    gray = Color(0xFF8E8E93),
)

/** Apple's text styles at the default Dynamic Type size, in their own point sizes. */
@Immutable
data class ShioriType(
    val largeTitle: TextStyle = TextStyle(fontSize = 34.sp, lineHeight = 41.sp, fontWeight = FontWeight.Bold),
    val title: TextStyle = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold),
    val title2: TextStyle = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold),
    val title3: TextStyle = TextStyle(fontSize = 20.sp, lineHeight = 25.sp, fontWeight = FontWeight.SemiBold),
    val headline: TextStyle = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold),
    val body: TextStyle = TextStyle(fontSize = 17.sp, lineHeight = 22.sp),
    val callout: TextStyle = TextStyle(fontSize = 16.sp, lineHeight = 21.sp),
    val subheadline: TextStyle = TextStyle(fontSize = 15.sp, lineHeight = 20.sp),
    val footnote: TextStyle = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    val caption: TextStyle = TextStyle(fontSize = 12.sp, lineHeight = 16.sp),
    val caption2: TextStyle = TextStyle(fontSize = 11.sp, lineHeight = 13.sp),
)

val LocalShioriColors = staticCompositionLocalOf { LightColors }
val LocalShioriType = staticCompositionLocalOf { ShioriType() }

object Shiori {
    val colors: ShioriColors
        @Composable @ReadOnlyComposable get() = LocalShioriColors.current
    val type: ShioriType
        @Composable @ReadOnlyComposable get() = LocalShioriType.current
}

private fun materialScheme(colors: ShioriColors): ColorScheme {
    val base = if (colors.isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = colors.accent,
        onPrimary = Color.White,
        background = colors.groupedBackground,
        onBackground = colors.label,
        surface = colors.secondaryGroupedBackground,
        onSurface = colors.label,
        surfaceVariant = colors.tertiaryGroupedBackground,
        onSurfaceVariant = colors.secondaryLabel,
        surfaceContainer = colors.secondaryGroupedBackground,
        surfaceContainerHigh = colors.secondaryGroupedBackground,
        surfaceContainerHighest = colors.tertiaryGroupedBackground,
        surfaceContainerLow = colors.secondaryGroupedBackground,
        error = colors.red,
        outline = colors.separator,
        outlineVariant = colors.separator,
    )
}

@Composable
fun ShioriTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (dark) DarkColors else LightColors
    CompositionLocalProvider(LocalShioriColors provides colors, LocalShioriType provides ShioriType()) {
        MaterialTheme(colorScheme = materialScheme(colors), content = content)
    }
}

@Preview(showBackground = true)
@Composable
private fun ShioriThemePreview() = PreviewSurface {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        with(Shiori.colors) { listOf(accent, blue, green, red, orange, yellow, pink, purple, gray) }.forEach {
            androidx.compose.material3.Surface(color = it) {
                androidx.compose.foundation.layout.Spacer(Modifier.padding(12.dp))
            }
        }
    }
}
