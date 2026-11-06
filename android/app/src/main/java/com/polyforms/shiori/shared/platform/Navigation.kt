package com.polyforms.shiori.shared.platform

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import com.polyforms.shiori.shared.components.styles.Shiori

/**
 * A NavigationStack: screens pushed over a root, each kept alive under the next one as iOS
 * keeps them, so coming back finds a screen where it was left. `push` is
 * `navigationDestination(item:)`: the caller hands the screen to show.
 */
class Navigator {
    internal class Entry(val id: Long, val content: @Composable () -> Unit)

    internal val entries = mutableStateListOf<Entry>()
    private var next = 0L

    val depth: Int get() = entries.size

    fun push(content: @Composable () -> Unit) {
        entries += Entry(next++, content)
    }

    fun pop() {
        if (entries.isNotEmpty()) entries.removeAt(entries.lastIndex)
    }

    fun popToRoot() = entries.clear()
}

val LocalNavigator = staticCompositionLocalOf<Navigator> { error("No navigator") }

/** The screens of one tab: the root, then everything pushed over it. */
@Composable
fun NavigationStack(navigator: Navigator = remember { Navigator() }, active: Boolean = true, root: @Composable () -> Unit) {
    CompositionLocalProvider(LocalNavigator provides navigator) {
        BackHandler(enabled = active && navigator.depth > 0) { navigator.pop() }
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val width = with(LocalDensity.current) { maxWidth.toPx() }
            val top = navigator.entries.lastIndex
            Layer(visible = top < 0) { root() }
            navigator.entries.forEachIndexed { index, entry ->
                key(entry.id) {
                    val offset = remember { Animatable(width) }
                    LaunchedEffect(Unit) { offset.animateTo(0f, tween(320)) }
                    Layer(
                        visible = index == top,
                        modifier = Modifier.graphicsLayer { translationX = offset.value },
                    ) { entry.content() }
                }
            }
        }
    }
}

/** A screen of the stack: drawn and touchable only on top, kept composed below. */
@Composable
private fun Layer(visible: Boolean, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(
        modifier
            .fillMaxSize()
            .graphicsLayer { alpha = if (visible) 1f else 0f }
            .background(Shiori.colors.groupedBackground)
            // A hit target over the whole screen, so a tap on its blank parts never reaches the
            // screen kept below it.
            .pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent() } },
    ) { content() }
}
