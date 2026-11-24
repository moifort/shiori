package com.polyforms.shiori.shared.platform

import androidx.compose.animation.animateColorAsState
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
 * The iOS 26 tab bar: a floating glass capsule of tabs, the chosen one on a lighter pill, and
 * one detached round button at its trailing end (the scanner).
 *
 * `minimized` folds it away while a page scrolls down, as iOS's `.onScrollDown`: only the chosen
 * tab stays, as a round button that unfolds the bar, beside the scanner. `accessory` (the title
 * playing) floats over the bar, and slides between the chosen tab and the scanner once folded.
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
) {
    val colors = Shiori.colors
    Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = BottomRoom.BarPadding)) {
        if (accessory != null && !minimized) {
            Box(Modifier.fillMaxWidth().padding(bottom = BottomRoom.AccessoryGap)) { accessory() }
        }
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (minimized) {
                val tab = tabs.firstOrNull { it.value == selected } ?: tabs.first()
                Box(
                    Modifier
                        .size(BottomRoom.BarHeight)
                        .shadow(12.dp, CircleShape, ambientColor = colors.label.copy(alpha = 0.2f), spotColor = colors.label.copy(alpha = 0.2f))
                        .clip(CircleShape)
                        .glass(CircleShape)
                        .plainClickable(onClick = onExpand)
                        .semantics { contentDescription = tab.label },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol(tab.symbol), null, Modifier.size(26.dp), tint = colors.accent)
                }
                Box(Modifier.weight(1f)) { accessory?.invoke() }
            } else {
                Row(
                    Modifier
                        .weight(1f)
                        .height(BottomRoom.BarHeight)
                        .shadow(12.dp, CircleShape, ambientColor = colors.label.copy(alpha = 0.2f), spotColor = colors.label.copy(alpha = 0.2f))
                        .clip(CircleShape)
                        .glass(CircleShape)
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
                                .plainClickable { onSelect(tab.value) },
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Icon(Symbol(tab.symbol), null, Modifier.size(24.dp), tint = tint)
                            Text(tab.label, style = Shiori.type.caption2.copy(fontSize = 10.sp, fontWeight = FontWeight.SemiBold), color = tint, maxLines = 1)
                        }
                    }
                }
            }
            if (trailing != null) {
                Box(
                    Modifier
                        .size(BottomRoom.BarHeight)
                        .shadow(12.dp, CircleShape, ambientColor = colors.label.copy(alpha = 0.2f), spotColor = colors.label.copy(alpha = 0.2f))
                        .clip(CircleShape)
                        .glass(CircleShape)
                        .plainClickable(onClick = onTrailing),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol(trailing.symbol), trailing.label, Modifier.size(28.dp), tint = colors.label)
                }
            }
        }
    }
}

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
