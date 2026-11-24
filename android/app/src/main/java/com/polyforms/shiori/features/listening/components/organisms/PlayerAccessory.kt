package com.polyforms.shiori.features.listening.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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

/** The accessory's height: the pill over the tab bar, and between its two round buttons. */
val PlayerAccessoryHeight = 56.dp

/**
 * The title playing, over the tab bar on every page: its cover, its title and, with room, the
 * chapter and the time left, pause and −30 s. When the bar folds away on a scroll, it slides
 * between the active tab and the scan button, and keeps the cover, the title and pause.
 *
 * iOS's system draws the glass there; here the accessory draws its own capsule.
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
    BoxWithConstraints(modifier.fillMaxWidth()) {
        // Between the folded bar's two round buttons there is room for little.
        val isInline = maxWidth < 260.dp
        Row(
            Modifier
                .fillMaxWidth()
                .height(PlayerAccessoryHeight)
                .shadow(12.dp, CircleShape, ambientColor = colors.label.copy(alpha = 0.2f), spotColor = colors.label.copy(alpha = 0.2f))
                .clip(CircleShape)
                .glass(CircleShape)
                .padding(start = 4.dp, end = if (isInline) 4.dp else 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(if (isInline) 4.dp else 8.dp),
        ) {
            Row(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .plainClickable(onClick = onOpen)
                    .semantics(mergeDescendants = true) { contentDescription = "${item.title}. ${L("Ouvre le lecteur")}" },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(if (isInline) 8.dp else 10.dp),
            ) {
                // Close to the capsule's edge, round as its end is.
                PlayerArtwork(item.coverURL, PlayerAccessoryHeight - 8.dp, isRound = true)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(if (isInline) 0.dp else 1.dp)) {
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
            Box(
                Modifier
                    .width(if (isInline) 32.dp else 40.dp)
                    .height(40.dp)
                    .plainClickable(enabled = !item.isLoading, onClick = onTogglePlay)
                    .semantics { contentDescription = if (item.isPlaying) L("Pause") else L("Lecture") },
                contentAlignment = Alignment.Center,
            ) {
                if (item.isLoading) {
                    CircularProgressIndicator(Modifier.size(20.dp), color = colors.secondaryLabel, strokeWidth = 2.dp)
                } else {
                    Icon(Symbol(if (item.isPlaying) "pause.fill" else "play.fill"), null, Modifier.size(if (isInline) 24.dp else 28.dp), tint = colors.label)
                }
            }
            // Room for it only over the bar: folded, pause alone.
            if (!isInline) {
                Box(
                    Modifier.size(40.dp).plainClickable(enabled = !item.isLoading, onClick = onSkipBack)
                        .semantics { contentDescription = L("Reculer de 30 secondes") },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Symbol("gobackward.30"), null, Modifier.size(26.dp), tint = colors.label.copy(alpha = if (item.isLoading) 0.4f else 1f))
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun PlayerAccessoryPreview() = PreviewSurface {
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        PlayerAccessory(PlayerAccessoryItem.preview, onOpen = {}, onTogglePlay = {}, onSkipBack = {})
        PlayerAccessory(PlayerAccessoryItem.preview.copy(isPlaying = false, isLoading = true), onOpen = {}, onTogglePlay = {}, onSkipBack = {})
        PlayerAccessory(PlayerAccessoryItem.preview, Modifier.width(220.dp), onOpen = {}, onTogglePlay = {}, onSkipBack = {})
    }
}
