package com.polyforms.shiori.features.news.components.organisms

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.series.components.pages.takenAs
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** The add menu of a News line: each format to read or already read, the wishlist, awaiting. */
fun newsRowMenu(
    format: BookFormat,
    owned: Boolean,
    wished: Boolean,
    awaited: Boolean,
    onAdd: (CopiedStatus, BookFormat) -> Unit,
    onWish: () -> Unit,
    onAwait: (ReleaseFormat) -> Unit,
): List<MenuEntry>? {
    val awaitable = if (format == BookFormat.AUDIOBOOK || awaited) emptyList() else listOf(ReleaseFormat.AUDIOBOOK)
    if (owned && awaitable.isEmpty()) return null
    return buildList {
        if (!owned) {
            format.takenAs.forEach { taken ->
                val audio = taken == BookFormat.AUDIOBOOK
                add(MenuEntry.Item("${taken.label} · ${if (audio) L("À écouter") else L("À lire")}", "bookmark.fill") { onAdd(CopiedStatus.TO_READ, taken) })
                add(MenuEntry.Item("${taken.label} · ${if (audio) L("Déjà écouté") else L("Déjà lu")}", "checkmark") { onAdd(CopiedStatus.READ, taken) })
                add(MenuEntry.Divider)
            }
            add(MenuEntry.Item(L("Liste d'envies"), if (wished) "checkmark" else "bookmark") { if (!wished) onWish() })
        }
        if (awaitable.isNotEmpty()) {
            if (!owned) add(MenuEntry.Divider)
            awaitable.forEach { add(MenuEntry.Item(it.awaitLabel, if (it == ReleaseFormat.AUDIOBOOK) "headphones" else "character.book.closed") { onAwait(it) }) }
        }
    }
}

/**
 * A line a swipe to the left, or a long press, opens a menu on: the chevron shows under the
 * line as it slides, a spring brings it back.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SwipeMenuBox(menu: List<MenuEntry>?, onTap: (() -> Unit)?, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val offset = remember { Animatable(0f) }
    var open by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    val threshold = with(density) { 56.dp.toPx() }
    val reach = with(density) { 72.dp.toPx() }
    Box(modifier.clipToBounds()) {
        if (menu != null) {
            Box(
                Modifier.align(Alignment.CenterEnd).padding(end = 16.dp).size(34.dp).alpha(minOf(1f, -offset.value / threshold))
                    .background(Shiori.colors.secondaryGroupedBackground, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Icon(Symbol("chevron.left"), null, Modifier.size(14.dp), tint = Shiori.colors.secondaryLabel) }
        }
        Box(
            Modifier.offset { IntOffset(offset.value.roundToInt(), 0) }
                .then(
                    if (menu == null) {
                        Modifier
                    } else {
                        Modifier.pointerInput(menu) {
                            var total = 0f
                            detectHorizontalDragGestures(
                                onDragStart = { total = 0f },
                                onDragEnd = {
                                    if (total <= -threshold) {
                                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                        open = true
                                    }
                                    scope.launch { offset.animateTo(0f, spring()) }
                                },
                                onDragCancel = { scope.launch { offset.animateTo(0f, spring()) } },
                            ) { _, drag ->
                                total += drag
                                val shown = minOf(0f, total)
                                scope.launch { offset.snapTo(if (shown >= -reach) shown else -reach + (shown + reach) / 3) }
                            }
                        }
                    },
                )
                .combinedClickable(
                    interactionSource = null,
                    indication = null,
                    enabled = onTap != null || menu != null,
                    onLongClick = menu?.let { { open = true } },
                    onClick = { onTap?.invoke() },
                ),
        ) { content() }
        if (menu != null) Box(Modifier.align(Alignment.CenterEnd).padding(end = 24.dp)) { MenuEntries(menu, open) { open = false } }
    }
}
