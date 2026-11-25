package com.polyforms.shiori.shared.platform

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.layoutId
import androidx.compose.ui.unit.Constraints
import com.polyforms.shiori.shared.components.styles.Motion
import com.polyforms.shiori.features.listening.components.organisms.PlayerAccessoryHeights
import kotlin.math.roundToInt
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable

/** One tab of the bar. */
data class TabItem<T>(val value: T, val label: String, val symbol: String)

/**
 * How far the tab bar has folded, 0 unfolded to 1 folded, for what floats with it (the title
 * playing) to follow the same spring. A lambda read in layout or draw, so a fold moves things
 * without composing anything again.
 */
val LocalBarFold = staticCompositionLocalOf<() -> Float> { { 0f } }

/** The fold of the bar, sprung as iOS folds its tab bar, from `minimized`. */
@Composable
fun animatedBarFold(minimized: Boolean): () -> Float {
    val progress = remember { Animatable(if (minimized) 1f else 0f) }
    LaunchedEffect(minimized) { progress.animateTo(if (minimized) 1f else 0f, Motion.snappy()) }
    return remember(progress) { { progress.value } }
}

/**
 * The iOS 26 tab bar: a floating glass capsule of tabs, the chosen one on a lighter pill, and
 * one detached round button at its trailing end (the scanner).
 *
 * `minimized` folds it away while a page scrolls down, as iOS's `.onScrollDown`: the capsule of
 * tabs shrinks to the chosen tab alone, a round button that unfolds the bar, beside the scanner.
 * `accessory` (the title playing) floats over the bar and, as the bar folds, slides down and
 * narrows into the room between the chosen tab and the scanner, one capsule all the way. The
 * whole move is laid out from `fold`, never composed again frame by frame.
 */
@Composable
fun <T> FloatingTabBar(
    tabs: List<TabItem<T>>,
    selected: T,
    onSelect: (T) -> Unit,
    trailing: TabItem<T>? = null,
    onTrailing: () -> Unit = {},
    minimized: Boolean = false,
    onExpand: () -> Unit = {},
    accessory: (@Composable () -> Unit)? = null,
    fold: () -> Float = animatedBarFold(minimized),
) {
    val colors = Shiori.colors
    val shadowColor = colors.label.copy(alpha = 0.2f)
    val chosen = tabs.firstOrNull { it.value == selected } ?: tabs.first()
    // The capsule of tabs' unfolded width, set as the bar is laid out, for its tabs to keep it.
    val fullTabsWidth = remember { IntArray(1) }
    Layout(
        modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = BottomRoom.BarPadding),
        content = {
            // The capsule of tabs, which folds into the chosen tab's round button.
            Box(
                Modifier
                    .layoutId(BarPart.Tabs)
                    .shadow(12.dp, CircleShape, ambientColor = shadowColor, spotColor = shadowColor)
                    .clip(CircleShape)
                    .glass(CircleShape),
            ) {
                // Laid out at the capsule's unfolded width, whatever its width now: the tabs fade
                // in place as the capsule closes over them rather than squeezing.
                Row(
                    Modifier
                        .layout { measurable, constraints ->
                            val full = constraints.maxWidth.coerceAtLeast(fullTabsWidth[0])
                            val placeable = measurable.measure(Constraints.fixed(full, constraints.maxHeight))
                            layout(constraints.maxWidth, constraints.maxHeight) { placeable.placeRelative(0, 0) }
                        }
                        .graphicsLayer { alpha = (1f - fold() / 0.6f).coerceIn(0f, 1f) }
                        .padding(4.dp),
                ) {
                    tabs.forEach { tab ->
                        val on = tab.value == selected
                        val tint by animateColorAsState(if (on) colors.accent else colors.label, label = "tab")
                        Column(
                            Modifier
                                .weight(1f)
                                .height(54.dp)
                                .clip(CircleShape)
                                .background(if (on) colors.fill else colors.fill.copy(alpha = 0f))
                                .plainClickable(enabled = !minimized) { onSelect(tab.value) },
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Icon(Symbol(tab.symbol), null, Modifier.size(24.dp), tint = tint)
                            Text(tab.label, style = Shiori.type.caption2.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold), color = tint, maxLines = 1)
                        }
                    }
                }
                // Folded, the chosen tab alone, centred in the round button it became.
                Box(
                    Modifier
                        .matchParentSize()
                        .graphicsLayer { alpha = ((fold() - 0.4f) / 0.6f).coerceIn(0f, 1f) }
                        .then(if (minimized) Modifier.plainClickable(onClick = onExpand).semantics { contentDescription = chosen.label } else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol(chosen.symbol), null, Modifier.size(26.dp), tint = colors.accent)
                }
            }
            if (accessory != null) {
                Box(Modifier.layoutId(BarPart.Accessory)) {
                    CompositionLocalProvider(LocalBarFold provides fold) { accessory() }
                }
            }
            if (trailing != null) {
                Box(
                    Modifier
                        .layoutId(BarPart.Trailing)
                        .shadow(12.dp, CircleShape, ambientColor = shadowColor, spotColor = shadowColor)
                        .clip(CircleShape)
                        .glass(CircleShape)
                        .plainClickable(onClick = onTrailing),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol(trailing.symbol), trailing.label, Modifier.size(28.dp), tint = colors.label)
                }
            }
        },
    ) { measurables, constraints ->
        val p = fold()
        val width = constraints.maxWidth
        val bar = BottomRoom.BarHeight.roundToPx()
        val spacing = 10.dp.roundToPx()
        val gap = BottomRoom.AccessoryGap.roundToPx()
        val hasTrailing = measurables.any { it.layoutId == BarPart.Trailing }
        val tabsFull = width - if (hasTrailing) bar + spacing else 0
        val accessoryMeasurable = measurables.firstOrNull { it.layoutId == BarPart.Accessory }
        val over = PlayerAccessoryHeights.expanded.roundToPx()
        val inline = PlayerAccessoryHeights.inline.roundToPx()

        val tabsWidth = lerp(tabsFull, bar, p)
        fullTabsWidth[0] = tabsFull
        val tabs = measurables.first { it.layoutId == BarPart.Tabs }.measure(Constraints.fixed(tabsWidth, bar))
        val trailingPlaceable = measurables.firstOrNull { it.layoutId == BarPart.Trailing }?.measure(Constraints.fixed(bar, bar))

        // Over the bar, the whole width; folded, the room between the round tab and the scanner.
        val accessoryX = lerp(0, bar + spacing, p)
        val accessoryWidth = lerp(width, width - (bar + spacing) - if (hasTrailing) bar + spacing else 0, p)
        val accessoryHeight = lerp(over, inline, p)
        val accessoryPlaceable = accessoryMeasurable?.measure(Constraints.fixed(accessoryWidth, accessoryHeight))

        // The bar's row sits at the foot; what floats over it takes its room only while unfolded.
        val height = bar + if (accessoryPlaceable != null) lerp(over + gap, 0, p) else 0
        val barTop = height - bar
        layout(width, height) {
            tabs.placeRelative(0, barTop)
            trailingPlaceable?.placeRelative(width - bar, barTop)
            accessoryPlaceable?.placeRelative(accessoryX, barTop + lerp(-(over + gap), (bar - inline) / 2, p))
        }
    }
}

private enum class BarPart { Tabs, Accessory, Trailing }

private fun lerp(from: Int, to: Int, fraction: Float): Int = (from + (to - from) * fraction).roundToInt()

/**
 * Folds the tab bar away while a page scrolls down and calls it back on the way up, as iOS's
 * `.tabBarMinimizeBehavior(.onScrollDown)`. Its [connection] goes on the tabs' container, which
 * hears every scroll of every page beneath it.
 */
class TabBarFold {
    var isMinimized by mutableStateOf(false)

    val connection = object : NestedScrollConnection {
        override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
            if (source != NestedScrollSource.UserInput) return Offset.Zero
            when {
                consumed.y < -6f -> isMinimized = true
                consumed.y > 6f || available.y > 0f -> isMinimized = false
            }
            return Offset.Zero
        }
    }
}

/**
 * What the floating tab bar, and the title playing over it, cover at the foot of the screen:
 * iOS hands the same height to every page as its bottom safe area, for free, through the tab bar
 * and `tabViewBottomAccessory`. One source for every scrolled page and everything that floats
 * at the foot of one, set by `ContentView` where the bar is drawn; null outside the tabs (a
 * sheet, a full-screen cover), where only the system navigation is covered.
 */
val LocalBottomCovered = compositionLocalOf<Dp?> { null }

object BottomRoom {
    /** The bar's capsule and the round buttons beside it. */
    val BarHeight = 62.dp

    /** The bar's own padding, above and below it. */
    val BarPadding = 6.dp

    /** Between the title playing and the bar. */
    val AccessoryGap = 8.dp

    /** The breathing room after a page's last element, as iOS pages end (`.padding(.bottom, 32)`). */
    val PageEndMargin = 32.dp

    /**
     * The height the bar covers over `navigation` (the system navigation inset), with the title
     * playing above it when `accessory` is its height. The bar unfolded, always: folded it covers
     * less, and a foot that shrank under the thumb would make the page's end jump.
     */
    fun covered(navigation: Dp, accessory: Dp?): Dp =
        navigation + BarPadding + BarHeight + BarPadding + (accessory?.let { it + AccessoryGap } ?: 0.dp)
}

/** What chrome covers at the foot of the screen here: the tab bar and the player, else the system navigation. */
@Composable
fun bottomCovered(): Dp =
    LocalBottomCovered.current ?: WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

/** The empty room a scrolled page leaves after its last element, for it to scroll fully clear of the bar and the player. */
@Composable
fun pageEndRoom(): Dp = bottomCovered() + BottomRoom.PageEndMargin
