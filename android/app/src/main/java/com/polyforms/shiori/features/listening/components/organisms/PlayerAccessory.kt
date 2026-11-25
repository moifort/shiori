package com.polyforms.shiori.features.listening.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import com.polyforms.shiori.shared.platform.LocalBarFold
import kotlin.math.roundToInt
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.listening.ListeningProgress
import com.polyforms.shiori.features.listening.ListeningText
import com.polyforms.shiori.features.listening.ListeningTitlePreview
import com.polyforms.shiori.features.listening.preview
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable

/** What the accessory draws. */
data class PlayerAccessoryItem(
    val title: String,
    /** "Chapitre 12 · 11h47 restantes", or why it does not play. */
    val line: String?,
    /** "Chap. 12 · 11h47", under the title once the bar has folded. */
    val shortLine: String? = null,
    val coverURL: String?,
    val isPlaying: Boolean,
    val isLoading: Boolean,
) {
    companion object {
        val preview = PlayerAccessoryItem(
            title = ListeningTitlePreview.title,
            line = ListeningText.accessoryLine(ListeningProgress.preview),
            shortLine = ListeningText.shortLine(ListeningProgress.preview),
            coverURL = ListeningTitlePreview.coverURL,
            isPlaying = true,
            isLoading = false,
        )
    }
}

/** The accessory's heights: over the unfolded tab bar, and inline, between the folded bar's round buttons. */
object PlayerAccessoryHeights {
    val expanded = 56.dp
    val inline = 50.dp
}

/** The accessory's height over the tab bar, the room it takes at a page's foot. */
val PlayerAccessoryHeight = PlayerAccessoryHeights.expanded

/** The glass left between the cover and the capsule's edge. */
val PlayerArtworkInset = 5.dp

/**
 * The title playing, over the tab bar on every page: its cover, its title and, with room, the
 * chapter and the time left, pause and −30 s. When the bar folds away on a scroll, it slides
 * between the active tab and the scan button, and keeps the cover, the title and pause.
 *
 * iOS's system draws the glass there; here the accessory draws its own capsule. The bar's fold
 * ([LocalBarFold]) narrows it in step: the cover, the gaps and pause are laid out from it, −30 s
 * shrinks away, and the lines switch to their short form halfway, the one thing composed again.
 */
@Composable
fun PlayerAccessory(
    item: PlayerAccessoryItem,
    modifier: Modifier = Modifier,
    onOpen: () -> Unit,
    onTogglePlay: () -> Unit,
    onSkipBack: () -> Unit,
) {
    val colors = Shiori.colors
    val fold = LocalBarFold.current
    val isInline by remember(fold) { derivedStateOf { fold() > 0.5f } }
    val artwork = PlayerAccessoryHeights.expanded - PlayerArtworkInset * 2
    val lineWidths = remember { IntArray(2) }
    Row(
        modifier
            .fillMaxWidth()
            .height(PlayerAccessoryHeight)
            .shadow(12.dp, CircleShape, ambientColor = colors.label.copy(alpha = 0.2f), spotColor = colors.label.copy(alpha = 0.2f))
            .clip(CircleShape)
            .glass(CircleShape)
            .padding(start = PlayerArtworkInset),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier
                .weight(1f)
                .fillMaxHeight()
                .plainClickable(onClick = onOpen)
                .semantics(mergeDescendants = true) { contentDescription = "${item.title}. ${L("Ouvre le lecteur")}" },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Round as the capsule's end is, with a thin ring of glass around it.
            PlayerArtwork(item.coverURL, artwork, Modifier.foldedSize(fold, artwork, PlayerAccessoryHeights.inline - PlayerArtworkInset * 2))
            Spacer(Modifier.foldedWidth(fold, 10.dp, 8.dp))
            Column(Modifier.weight(1f).settledWidth(fold, lineWidths), verticalArrangement = Arrangement.spacedBy(if (isInline) 0.dp else 1.dp)) {
                Text(
                    item.title,
                    style = (if (isInline) Shiori.type.footnote else Shiori.type.subheadline).copy(fontWeight = FontWeight.SemiBold),
                    color = colors.label,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                (if (isInline) item.shortLine ?: item.line else item.line)?.let {
                    Text(
                        it,
                        style = if (isInline) Shiori.type.caption2 else Shiori.type.caption,
                        color = colors.secondaryLabel,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        Spacer(Modifier.foldedWidth(fold, 8.dp, 4.dp))
        Box(
            Modifier
                .foldedWidth(fold, 40.dp, 32.dp)
                .height(40.dp)
                .plainClickable(enabled = !item.isLoading, onClick = onTogglePlay)
                .semantics { contentDescription = if (item.isPlaying) L("Pause") else L("Lecture") },
            contentAlignment = Alignment.Center,
        ) {
            if (item.isLoading) {
                CircularProgressIndicator(Modifier.size(20.dp), color = colors.secondaryLabel, strokeWidth = 2.dp)
            } else {
                Icon(
                    Symbol(if (item.isPlaying) "pause.fill" else "play.fill"),
                    null,
                    Modifier.size(28.dp).graphicsLayer {
                        val scale = 1f - fold() * (4f / 28f)
                        scaleX = scale
                        scaleY = scale
                    },
                    tint = colors.label,
                )
            }
        }
        // Room for it only over the bar: as the bar folds it shrinks away, leaving pause alone.
        Box(
            Modifier
                .foldedWidth(fold, 48.dp, 0.dp, content = 40.dp, contentStart = 8.dp)
                .height(40.dp)
                .graphicsLayer { alpha = (1f - fold() * 2f).coerceIn(0f, 1f) }
                .then(
                    if (isInline) {
                        Modifier.clearAndSetSemantics {}
                    } else {
                        Modifier.plainClickable(enabled = !item.isLoading, onClick = onSkipBack)
                            .semantics { contentDescription = L("Reculer de 30 secondes") }
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Symbol("gobackward.30"), null, Modifier.size(26.dp), tint = colors.label.copy(alpha = if (item.isLoading) 0.4f else 1f))
        }
        Spacer(Modifier.foldedWidth(fold, 8.dp, 4.dp))
    }
}

/**
 * A width laid out from the bar's fold, `from` unfolded to `to` folded. The content keeps
 * `content` (the unfolded width by default), placed `contentStart` in, so it slides out of a
 * shrinking slot rather than squeezing.
 */
private fun Modifier.foldedWidth(fold: () -> Float, from: Dp, to: Dp, content: Dp = from, contentStart: Dp = 0.dp): Modifier =
    layout { measurable, constraints ->
        val width = (from.toPx() + (to.toPx() - from.toPx()) * fold()).roundToInt().coerceAtLeast(0)
        val inner = content.roundToPx()
        val placeable = measurable.measure(Constraints(minWidth = inner, maxWidth = inner, minHeight = constraints.minHeight, maxHeight = constraints.maxHeight))
        layout(width, placeable.height) { placeable.placeRelative(contentStart.roundToPx(), 0) }
    }

/**
 * Lays the lines out at the width they have once the bar has settled, unfolded until halfway and
 * folded after, clipped to the room they have meanwhile: text measured afresh at every frame of
 * the fold would cost more than all the rest of it.
 */
private fun Modifier.settledWidth(fold: () -> Float, widths: IntArray): Modifier =
    clipToBounds().layout { measurable, constraints ->
        val progress = fold()
        if (progress == 0f) widths[0] = constraints.maxWidth
        if (progress == 1f) widths[1] = constraints.maxWidth
        val settled = widths[if (progress <= 0.5f) 0 else 1]
        val width = if (settled > 0) settled else constraints.maxWidth
        val placeable = measurable.measure(constraints.copy(minWidth = 0, maxWidth = width))
        layout(constraints.maxWidth, placeable.height) { placeable.placeRelative(0, 0) }
    }

/** A square drawn at `from` and laid out and scaled down to `to` as the bar folds, from its centre. */
private fun Modifier.foldedSize(fold: () -> Float, from: Dp, to: Dp): Modifier =
    layout { measurable, _ ->
        val full = from.roundToPx()
        val side = (from.toPx() + (to.toPx() - from.toPx()) * fold()).roundToInt()
        val placeable = measurable.measure(Constraints.fixed(full, full))
        layout(side, side) {
            val offset = (side - full) / 2
            placeable.placeRelativeWithLayer(offset, offset) {
                val scale = side.toFloat() / full
                scaleX = scale
                scaleY = scale
            }
        }
    }

@Preview(showBackground = true)
@Composable
private fun PlayerAccessoryPreview() = PreviewSurface {
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PlayerAccessory(PlayerAccessoryItem.preview, onOpen = {}, onTogglePlay = {}, onSkipBack = {})
        PlayerAccessory(PlayerAccessoryItem.preview.copy(isPlaying = false, isLoading = true), onOpen = {}, onTogglePlay = {}, onSkipBack = {})
        CompositionLocalProvider(LocalBarFold provides { 1f }) {
            PlayerAccessory(PlayerAccessoryItem.preview, Modifier.width(220.dp).height(PlayerAccessoryHeights.inline), onOpen = {}, onTogglePlay = {}, onSkipBack = {})
        }
    }
}
