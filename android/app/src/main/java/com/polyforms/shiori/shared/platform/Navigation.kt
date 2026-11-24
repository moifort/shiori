package com.polyforms.shiori.shared.platform

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import com.polyforms.shiori.shared.components.styles.Shiori

/**
 * A NavigationStack: screens pushed over a root, each kept alive under the next one as iOS
 * keeps them, so coming back finds a screen where it was left. `push` is
 * `navigationDestination(item:)`: the caller hands the screen to show.
 */
class Navigator {
    internal class Entry(val id: Long, val content: @Composable () -> Unit) {
        /** Popped, and sliding out before it leaves the stack. */
        var isLeaving by mutableStateOf(false)

        /** Where the screen is on its way in or out: 1 off the trailing edge, 0 in place. */
        val slide = Animatable(1f)
    }

    internal val entries = mutableStateListOf<Entry>()
    private var next = 0L

    /** The screens pushed and still there: one sliding out no longer counts. */
    val depth: Int get() = entries.count { !it.isLeaving }

    fun push(content: @Composable () -> Unit) {
        entries += Entry(next++, content)
    }

    fun pop() {
        entries.lastOrNull { !it.isLeaving }?.isLeaving = true
    }

    /** Back to the root: the top screen slides out, the ones under it go at once. */
    fun popToRoot() {
        val top = entries.lastOrNull { !it.isLeaving }
        entries.removeAll { it !== top && !it.isLeaving }
        top?.isLeaving = true
    }

    internal fun remove(entry: Entry) {
        entries.remove(entry)
    }
}

val LocalNavigator = staticCompositionLocalOf<Navigator?> { null }

/** The navigator of the stack the calling screen is in. */
val currentNavigator: Navigator
    @Composable get() = LocalNavigator.current ?: error("No navigation stack around this screen")

/** A push and a pop, as UIKit's: a critically damped spring of about half a second. */
private val slideSpring = spring<Float>(dampingRatio = 1f, stiffness = 380f, visibilityThreshold = 0.0005f)

/** How far a screen draws back, in widths, under the one sliding over it. */
private const val PARALLAX = 0.3f

/** The screens of one tab: the root, then everything pushed over it. */
@Composable
fun NavigationStack(navigator: Navigator = remember { Navigator() }, active: Boolean = true, root: @Composable () -> Unit) {
    CompositionLocalProvider(LocalNavigator provides navigator) {
        BackHandler(enabled = active && navigator.depth > 0) { navigator.pop() }
        Box(Modifier.fillMaxSize()) {
            Layer(navigator, index = -1) { root() }
            navigator.entries.forEachIndexed { index, entry ->
                key(entry.id) {
                    LaunchedEffect(entry.isLeaving) {
                        if (entry.isLeaving) {
                            entry.slide.animateTo(1f, slideSpring)
                            navigator.remove(entry)
                        } else {
                            entry.slide.animateTo(0f, slideSpring)
                        }
                    }
                    Layer(navigator, index) { entry.content() }
                }
            }
        }
    }
}

/**
 * A screen of the stack, kept composed whatever lies over it. It is drawn while nothing covers
 * it whole: on top, or under a screen on its way in or out, drawn back a little as iOS does. The
 * slide is read in the layer alone, so a push or a pop recomposes nothing.
 */
@Composable
private fun Layer(navigator: Navigator, index: Int, content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .graphicsLayer {
                val entries = navigator.entries
                val own = entries.getOrNull(index)?.slide?.value ?: 0f
                var isCovered = false
                for (above in index + 1 until entries.size) if (entries[above].slide.value == 0f) isCovered = true
                val over = entries.getOrNull(index + 1)?.slide?.value ?: 1f
                alpha = if (isCovered) 0f else 1f
                translationX = size.width * (own - PARALLAX * (1f - over))
            }
            .background(Shiori.colors.groupedBackground)
            // A hit target over the whole screen, so a tap on its blank parts never reaches the
            // screen kept below it.
            .pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent() } },
    ) {
        // A pushed screen holds its bar's title.
        if (index >= 0) {
            CompositionLocalProvider(LocalScreenTitle provides remember { ScreenTitle() }) { content() }
        } else {
            content()
        }
    }
}
