package com.polyforms.shiori.features.listening.components.pages

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.listening.AudiblePlayer
import com.polyforms.shiori.features.listening.ListeningProgress
import com.polyforms.shiori.features.listening.ListeningQueueEntry
import com.polyforms.shiori.features.listening.ListeningQueuePreviews
import com.polyforms.shiori.features.listening.ListeningText
import com.polyforms.shiori.features.listening.ListeningTitle
import com.polyforms.shiori.features.listening.ListeningTitlePreview
import com.polyforms.shiori.features.listening.components.organisms.PlayerArtwork
import com.polyforms.shiori.features.listening.preview
import com.polyforms.shiori.shared.CoverEffect
import com.polyforms.shiori.shared.CoverEffectImage
import com.polyforms.shiori.shared.components.styles.Motion
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.Pill
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.DarkColors
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.LocalShioriColors
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glassOnDark
import com.polyforms.shiori.shared.components.styles.iconGesture
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Everything the full-screen player can ask for. */
sealed interface PlayerAction {
    data object TogglePlay : PlayerAction
    data class Skip(val seconds: Double) : PlayerAction
    data object PreviousChapter : PlayerAction
    data object NextChapter : PlayerAction
    data class Seek(val position: Double) : PlayerAction
    data class Sleep(val minutes: Int) : PlayerAction

    /** The three dots: the player gives way to the book's page. */
    data object OpenBook : PlayerAction

    /** A book of the queue, played in place of this one. */
    data class Play(val title: ListeningTitle) : PlayerAction
}

/** What the full-screen player draws. */
data class PlayerPageItem(
    val title: String,
    val subtitle: String?,
    val coverURL: String?,
    val progress: ListeningProgress,
    val isPlaying: Boolean,
    val isLoading: Boolean,
    /** Why it does not play, in place of the time left. */
    val failure: String?,
    /** The sleep timer's choice, while it runs. */
    val sleepMinutes: Int?,
    /** Whether the title has a book in the library to open. */
    val hasBook: Boolean = true,
    /** What follows this title; null while it loads. */
    val queue: List<ListeningQueueEntry>? = null,
) {
    companion object {
        val preview = PlayerPageItem(
            title = ListeningTitlePreview.title,
            subtitle = ListeningTitlePreview.subtitle,
            coverURL = ListeningTitlePreview.coverURL,
            progress = ListeningProgress.preview,
            isPlaying = true,
            isLoading = false,
            failure = null,
            sleepMinutes = null,
        )
    }
}

/**
 * Where the player's big cover sits in the window, for the sheet to fly it into the pill's round
 * cover. Null outside the sheet.
 */
val LocalPlayerArtworkFrame = compositionLocalOf<((Rect) -> Unit)?> { null }

private val White70 = Color.White.copy(alpha = 0.7f)
private val BannerArtwork = 64.dp
private const val ControlsScale = 0.8f
private val HandleHeight = 60.dp

private fun artworkSize(width: Dp): Dp = min(300f, width.value - 38).dp

private fun mix(from: Float, to: Float, progress: Float) = from + (to - from) * progress

/** An opacity along the pull. With `to` 0, it fades out until `from`; otherwise it fades in between `from` and `to`. */
private fun ramp(progress: Float, from: Float, to: Float): Float =
    if (to == 0f) max(0f, 1 - progress / from) else ((progress - from) / (to - from)).coerceIn(0f, 1f)

/**
 * The full-screen player, over its cover's colours: the cover, the title and the series, the
 * chapter's bar with where the listener is in it, the chapter and ±30 s controls, the time left
 * in the book, and the sleep timer set in one touch. Under it, the queue: pulled up, in the same
 * sheet, the player shrinks with the finger (the cover to a banner, the controls smaller, the
 * sleep timer gone) and the audiobooks that follow this one rise in its place, each played with
 * a touch.
 *
 * `queueProgress` opens it partway, as a finger leaves it: for previews.
 */
@Composable
fun PlayerPage(item: PlayerPageItem, queueProgress: Float = 0f, onAction: (PlayerAction) -> Unit) {
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    // How far the queue is pulled up: 0 is the whole player, 1 the queue over the shrunk player.
    val queue = remember { Animatable(queueProgress) }
    // The spring runs a little past its ends: what is drawn stays between them.
    val progress = queue.value.coerceIn(0f, 1f)
    fun setQueueOpen(open: Boolean) {
        scope.launch { queue.animateTo(if (open) 1f else 0f, Motion.snappy()) }
    }
    CompositionLocalProvider(LocalShioriColors provides DarkColors) {
        BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black)) {
            PlayerBackdrop(item.coverURL, Modifier.fillMaxSize())
            val width = maxWidth - 64.dp
            val full = artworkSize(width)
            val scale = mix(1f, BannerArtwork / full, progress)
            // The handle travels from the foot of the page to under the controls: the finger and
            // the handle move together.
            val travel = with(density) { max(240f, maxHeight.value - 330).dp.toPx() }
            fun dragBy(delta: Float) {
                scope.launch { queue.snapTo((queue.value - delta / travel).coerceIn(0f, 1f)) }
            }
            fun settle(velocity: Float) = setQueueOpen((queue.value - velocity * 0.2f / travel).coerceIn(0f, 1f) > 0.5f)
            val handleDrag = Modifier.draggable(
                rememberDraggableState(::dragBy),
                Orientation.Vertical,
                onDragStopped = { settle(it) },
            )
            // The list pulled down from its top folds the queue away the same way.
            val listPull = remember(travel) {
                object : NestedScrollConnection {
                    override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                        if (queue.value >= 1f || source != NestedScrollSource.UserInput) return Offset.Zero
                        dragBy(available.y)
                        return available
                    }

                    override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                        if (available.y <= 0 || source != NestedScrollSource.UserInput) return Offset.Zero
                        dragBy(available.y)
                        return available
                    }

                    override suspend fun onPreFling(available: Velocity): Velocity {
                        if (queue.value >= 1f) return Velocity.Zero
                        settle(available.y)
                        return available
                    }
                }
            }
            val reportArtwork = LocalPlayerArtworkFrame.current
            QueueRevealLayout(progress, Modifier.fillMaxSize().padding(horizontal = 32.dp)) {
                PlayerArtwork(
                    item.coverURL,
                    full,
                    Modifier
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                            transformOrigin = TransformOrigin(0f, 0f)
                        }
                        .shadow((mix(25f, 10f, progress) / scale).dp, RoundedCornerShape((mix(12f, 8f, progress) / scale).dp), ambientColor = Color.Black, spotColor = Color.Black)
                        // Where it shows, for the sheet to fly it into the pill.
                        .onGloballyPositioned { reportArtwork?.invoke(it.boundsInRoot()) },
                    cornerRadius = (mix(12f, 8f, progress) / scale).dp,
                )
                Box(Modifier.graphicsLayer { alpha = ramp(progress, 0.3f, 0f) }.unread(progress >= 0.3f)) { Heading(item, progress < 0.3f, onAction) }
                Box(Modifier.graphicsLayer { alpha = ramp(progress, 0.55f, 1f) }.unread(progress < 0.5f)) { Banner(item, progress >= 0.5f, onAction) }
                ChapterBar(item, onAction)
                Box(
                    Modifier.graphicsLayer {
                        val shrunk = mix(1f, ControlsScale, progress)
                        scaleX = shrunk
                        scaleY = shrunk
                        transformOrigin = TransformOrigin(0.5f, 0f)
                    },
                ) { Controls(item, onAction) }
                Column(
                    Modifier.graphicsLayer { alpha = ramp(progress, 0.3f, 0f) }.unread(progress > 0f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    // Why it does not play; the time left in the book sits under the title.
                    // Waiting for the network shows nothing: it happens in silence.
                    item.failure?.let { Text(it, style = Shiori.type.footnote, color = White70) }
                    SleepTimerRow(item, progress == 0f, onAction)
                }
                Box(Modifier.graphicsLayer { alpha = ramp(progress, 0.3f, 0f) }.unread(progress >= 0.5f).then(if (progress < 0.5f) handleDrag else Modifier)) {
                    OpenQueueHandle(progress < 0.5f) { setQueueOpen(true) }
                }
                Box(Modifier.graphicsLayer { alpha = ramp(progress, 0.2f, 0.55f) }.unread(progress < 0.5f).then(if (progress >= 0.5f) handleDrag else Modifier)) {
                    QueueHeader(progress >= 0.5f) { setQueueOpen(false) }
                }
                // Only there once pulled; its rows play only once it is wholly up.
                if (progress > 0f) {
                    Box(Modifier.graphicsLayer { alpha = progress }.unread(progress < 1f).nestedScroll(listPull)) {
                        QueueList(item.queue, progress == 1f) {
                            setQueueOpen(false)
                            onAction(PlayerAction.Play(it))
                        }
                    }
                } else {
                    Spacer(Modifier)
                }
            }
        }
    }
}

/**
 * Out of a screen reader's reach while `off`. The finger is kept away by the part itself, which
 * drops its own taps (`enabled`): a part that takes none lets the one drawn under it answer.
 */
private fun Modifier.unread(off: Boolean): Modifier = if (off) clearAndSetSemantics {} else this

private fun Modifier.tappable(enabled: Boolean, onClick: () -> Unit): Modifier = if (enabled) plainClickable(onClick = onClick) else this

@Composable
private fun Heading(item: PlayerPageItem, enabled: Boolean, onAction: (PlayerAction) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(item.title, style = Shiori.type.title2, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
            item.subtitle?.let { Text(it, style = Shiori.type.body, color = White70, maxLines = 1, overflow = TextOverflow.Ellipsis) }
            BookLeft(item, Modifier.padding(top = 2.dp))
        }
        BookButton(item, enabled, onAction)
    }
}

/** The heading shrunk beside the small cover, over the pulled-up queue. */
@Composable
private fun Banner(item: PlayerPageItem, enabled: Boolean, onAction: (PlayerAction) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(item.title, style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            item.subtitle?.let { Text(it, style = Shiori.type.subheadline, color = White70, maxLines = 1, overflow = TextOverflow.Ellipsis) }
            BookLeft(item)
        }
        BookButton(item, enabled, onAction)
    }
}

/**
 * "11h47 restantes · 46%", under the subtitle; nothing while the recording's length is unknown or
 * it fails.
 */
@Composable
private fun BookLeft(item: PlayerPageItem, modifier: Modifier = Modifier) {
    if (item.failure != null || item.progress.duration <= 0) return
    Text(
        ListeningText.summary(item.progress),
        modifier,
        style = Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
        color = White70,
        maxLines = 1,
    )
}

@Composable
private fun BookButton(item: PlayerPageItem, enabled: Boolean, onAction: (PlayerAction) -> Unit) {
    Box(
        Modifier
            .size(36.dp)
            .graphicsLayer { alpha = if (item.hasBook) 1f else 0.45f }
            .clip(CircleShape)
            .glassOnDark(CircleShape)
            .tappable(enabled && item.hasBook) { onAction(PlayerAction.OpenBook) }
            .semantics { contentDescription = L("Fiche du livre") },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol("ellipsis"), null, Modifier.size(20.dp), tint = Color.White)
    }
}

@Composable
private fun Grabber() = Box(Modifier.size(36.dp, 5.dp).background(Color.White.copy(alpha = 0.5f), CircleShape))

/** At the foot of the player: touched, it opens the queue; pulled up, the queue follows the finger. */
@Composable
private fun OpenQueueHandle(enabled: Boolean, onOpen: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(min = HandleHeight)
            .tappable(enabled, onOpen)
            .padding(top = 12.dp)
            .semantics(mergeDescendants = true) { role = Role.Button },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Grabber()
        Text(L("À suivre"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = White70)
    }
}

/** Over the queue: touched, it folds the queue away; pulled down, the player grows back with the finger. */
@Composable
private fun QueueHeader(enabled: Boolean, onClose: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().tappable(enabled, onClose).clearAndSetSemantics {
            contentDescription = L("Replier la file")
            role = Role.Button
        },
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.fillMaxWidth().heightIn(min = 24.dp), contentAlignment = Alignment.Center) { Grabber() }
        Text(L("À suivre"), style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color.White)
    }
}

@Composable
private fun QueueList(queue: List<ListeningQueueEntry>?, enabled: Boolean, onPlay: (ListeningTitle) -> Unit) {
    when {
        queue == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(Modifier.size(28.dp), color = Color.White, strokeWidth = 2.5.dp)
        }
        queue.isEmpty() -> EmptyState(
            symbol = "text.line.first.and.arrowtriangle.forward",
            title = L("Rien à suivre"),
            message = L("Les livres audio en cours et à lire s'enchaîneront ici, une fois ce livre fini."),
        )
        else -> LazyColumn(Modifier.fillMaxSize()) {
            items(queue, key = { it.id }) { entry -> QueueRow(entry, enabled) { onPlay(entry.title) } }
        }
    }
}

@Composable
private fun QueueRow(entry: ListeningQueueEntry, enabled: Boolean, onPlay: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .height(76.dp)
            .tappable(enabled, onPlay)
            .semantics(mergeDescendants = true) { contentDescription = L("Écouter %@", entry.title.title) },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        PlayerArtwork(entry.title.coverURL, 56.dp, cornerRadius = 6.dp)
        Box(Modifier.weight(1f).fillMaxHeight()) {
            Column(Modifier.align(Alignment.CenterStart), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        entry.title.title,
                        Modifier.weight(1f),
                        style = Shiori.type.body.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    entry.heard?.let { Pill("$it %", style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold)) }
                }
                entry.title.subtitle?.let {
                    Text(it, style = Shiori.type.subheadline, color = White70, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Box(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(0.5.dp).background(Color.White.copy(alpha = 0.14f)))
        }
    }
}

@Composable
private fun ChapterBar(item: PlayerPageItem, onAction: (PlayerAction) -> Unit) {
    // Where a finger dragging the bar holds it, from 0 to 1.
    var scrubbing by remember { mutableStateOf<Float?>(null) }
    val progress = item.progress
    val chapter = progress.chapter
    val fraction = scrubbing?.toDouble() ?: progress.chapterFraction
    val shownElapsed = chapter?.let { fraction * it.length } ?: progress.chapterElapsed
    val shownRemaining = chapter?.let { it.length - shownElapsed } ?: progress.chapterRemaining
    val thickness by animateDpAsState(if (scrubbing == null) 6.dp else 10.dp, label = "bar")
    val enabled = !item.isLoading && chapter != null
    val labels = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum")
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(22.dp)
                .semantics {
                    contentDescription = L("Position dans le chapitre")
                    stateDescription = ListeningText.clock(shownElapsed)
                }
                .then(
                    if (!enabled) {
                        Modifier
                    } else {
                        Modifier.pointerInput(chapter) {
                            awaitEachGesture {
                                val down = awaitFirstDown()
                                down.consume()
                                scrubbing = (down.position.x / size.width).coerceIn(0f, 1f)
                                while (true) {
                                    val change = awaitPointerEvent().changes.firstOrNull { it.id == down.id } ?: break
                                    if (!change.pressed) break
                                    change.consume()
                                    scrubbing = (change.position.x / size.width).coerceIn(0f, 1f)
                                }
                                scrubbing?.let { if (chapter != null) onAction(PlayerAction.Seek(chapter.start + it * chapter.length)) }
                                scrubbing = null
                            }
                        }
                    },
                ),
            contentAlignment = Alignment.CenterStart,
        ) {
            Box(Modifier.fillMaxWidth().height(thickness).clip(CircleShape).background(Color.White.copy(alpha = 0.25f))) {
                Box(Modifier.fillMaxWidth(fraction.toFloat().coerceIn(0f, 1f)).fillMaxHeight().background(Color.White, CircleShape))
            }
        }
        Box(Modifier.fillMaxWidth()) {
            Text(ListeningText.clock(shownElapsed), Modifier.align(Alignment.CenterStart), style = labels, color = White70)
            ListeningText.chapterOfCount(progress)?.let {
                Text(it, Modifier.align(Alignment.Center), style = labels, color = Color.White, maxLines = 1)
            }
            Text("−${ListeningText.clock(shownRemaining)}", Modifier.align(Alignment.CenterEnd), style = labels, color = White70)
        }
    }
}

@Composable
private fun Controls(item: PlayerPageItem, onAction: (PlayerAction) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        ControlButton("backward.end.fill", 30.dp, L("Chapitre précédent"), !item.isLoading) { onAction(PlayerAction.PreviousChapter) }
        ControlButton("gobackward.30", 38.dp, L("Reculer de 30 secondes"), !item.isLoading) { onAction(PlayerAction.Skip(-AudiblePlayer.SKIP_INTERVAL)) }
        Box(
            Modifier
                .size(80.dp)
                .plainClickable(enabled = !item.isLoading) { onAction(PlayerAction.TogglePlay) }
                .semantics { contentDescription = if (item.isPlaying) L("Pause") else L("Lecture") },
            contentAlignment = Alignment.Center,
        ) {
            if (item.isLoading) {
                CircularProgressIndicator(Modifier.size(36.dp), color = Color.White, strokeWidth = 3.dp)
            } else {
                Icon(Symbol(if (item.isPlaying) "pause.fill" else "play.fill"), null, Modifier.size(64.dp), tint = Color.White)
            }
        }
        ControlButton("goforward.30", 38.dp, L("Avancer de 30 secondes"), !item.isLoading) { onAction(PlayerAction.Skip(AudiblePlayer.SKIP_INTERVAL)) }
        ControlButton("forward.end.fill", 30.dp, L("Chapitre suivant"), !item.isLoading && item.progress.nextChapterStart != null) {
            onAction(PlayerAction.NextChapter)
        }
    }
}

@Composable
private fun ControlButton(symbol: String, size: Dp, label: String, enabled: Boolean, action: () -> Unit) {
    Box(
        Modifier.size(52.dp).graphicsLayer { alpha = if (enabled) 1f else 0.4f }.plainClickable(enabled = enabled, onClick = action)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol(symbol), null, Modifier.size(size), tint = Color.White)
    }
}

@Composable
private fun SleepTimerRow(item: PlayerPageItem, enabled: Boolean, onAction: (PlayerAction) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(
            Symbol("moon"),
            null,
            Modifier.padding(end = 4.dp).size(22.dp).iconGesture(IconGesture.ROCK, item.sleepMinutes),
            tint = Color.White,
        )
        AudiblePlayer.SLEEP_CHOICES.forEach { minutes ->
            val isOn = item.sleepMinutes == minutes
            ActionButton(
                onClick = { onAction(PlayerAction.Sleep(minutes)) },
                fill = if (isOn) ActionFill.WHITE else ActionFill.GLASS,
                height = 40.dp,
                inert = !enabled,
                contentDescription = L("Arrêter dans %lld minutes", minutes),
            ) {
                Text(
                    L("%lld min", minutes),
                    style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = if (isOn) Color.Black else Color.White,
                )
            }
        }
    }
}

/**
 * The player's ground: its cover, blown up and blurred, over black. The sheet draws it too, so
 * the colours stay while it shrinks into its pill.
 */
@Composable
fun PlayerBackdrop(coverURL: String?, modifier: Modifier = Modifier) {
    Box(modifier.background(Color.Black).clipToBounds().clearAndSetSemantics {}) {
        if (coverURL != null) {
            CoverEffectImage(
                coverURL,
                CoverEffect.Backdrop,
                Modifier.fillMaxSize().graphicsLayer {
                    scaleX = 1.6f
                    scaleY = 1.6f
                },
            )
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)))
        }
    }
}

/**
 * Lays the player out between its two states, `progress` from 0 (the whole player, the queue's
 * handle at the foot) to 1 (the cover shrunk beside the title, the controls under it, the queue
 * below). Every part is measured and placed in between, so a finger moves them all at once.
 * Children, in order: cover, heading, banner, chapter bar, controls, sleep timer, the handle at
 * the foot, the queue's header, the queue's list.
 */
@Composable
private fun QueueRevealLayout(progress: Float, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content, modifier) { measurables, constraints ->
        val width = constraints.maxWidth
        val height = constraints.maxHeight
        if (measurables.size != 9) return@Layout layout(width, height) {}
        val p = progress.coerceIn(0f, 1f)
        fun mixed(from: Float, to: Float) = from + (to - from) * p
        fun wide(pixels: Int) = Constraints(minWidth = pixels.coerceAtLeast(0), maxWidth = pixels.coerceAtLeast(0))

        val full = artworkSize(width.toDp()).toPx()
        val small = BannerArtwork.toPx()
        val coverSide = mixed(full, small)
        val bannerLeft = coverSide + 14.dp.toPx()

        val cover = measurables[0].measure(Constraints())
        val heading = measurables[1].measure(wide(width))
        val banner = measurables[2].measure(wide((width - bannerLeft).roundToInt()))
        val bar = measurables[3].measure(wide(width))
        val controls = measurables[4].measure(wide(width))
        val sleep = measurables[5].measure(wide(width))
        val handle = measurables[6].measure(wide(width).copy(minHeight = HandleHeight.roundToPx(), maxHeight = HandleHeight.roundToPx()))
        val header = measurables[7].measure(wide(width))

        // The whole player.
        val foldedCover = 48.dp.toPx()
        val foldedHandle = height - HandleHeight.toPx()
        // The queue pulled up.
        val openCover = 40.dp.toPx()
        val openBar = openCover + small + 30.dp.toPx()
        val openControls = openBar + bar.height + 14.dp.toPx()
        val openHeader = openControls + controls.height * ControlsScale + 10.dp.toPx()

        // Every part hangs from the one above it, so nothing crosses on the way: the heading's
        // room closes as it fades.
        val coverY = mixed(foldedCover, openCover)
        val coverBottom = coverY + coverSide
        val barY = coverBottom + mixed(30.dp.toPx() + heading.height + 22.dp.toPx(), 30.dp.toPx())
        val controlsY = barY + bar.height + mixed(26.dp.toPx(), 14.dp.toPx())
        val controlsShown = controls.height * mixed(1f, ControlsScale)
        val handleY = mixed(foldedHandle, openHeader)
        val listY = handleY + header.height + 10.dp.toPx()
        val list = measurables[8].measure(
            Constraints.fixed(width, (height - listY).roundToInt().coerceAtLeast(0)),
        )

        layout(width, height) {
            cover.place(mixed((width - full) / 2, 0f).roundToInt(), coverY.roundToInt())
            heading.place(0, (coverBottom + 30.dp.toPx()).roundToInt())
            banner.place(bannerLeft.roundToInt(), (coverY + (coverSide - banner.height) / 2).roundToInt())
            bar.place(0, barY.roundToInt())
            controls.place(0, controlsY.roundToInt())
            sleep.place(0, (controlsY + controlsShown + 26.dp.toPx()).roundToInt())
            handle.place(0, handleY.roundToInt())
            header.place(0, handleY.roundToInt())
            list.place(0, listY.roundToInt())
        }
    }
}

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPagePreview() = PreviewSurface(dark = true) { PlayerPage(PlayerPageItem.preview) {} }

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPageQueuePreview() = PreviewSurface(dark = true) {
    PlayerPage(PlayerPageItem.preview.copy(queue = ListeningQueuePreviews), queueProgress = 1f) {}
}

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPageQueueEmptyPreview() = PreviewSurface(dark = true) {
    PlayerPage(PlayerPageItem.preview.copy(queue = emptyList()), queueProgress = 1f) {}
}

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPageQueueHalfwayPreview() = PreviewSurface(dark = true) {
    PlayerPage(PlayerPageItem.preview.copy(queue = ListeningQueuePreviews), queueProgress = 0.45f) {}
}

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPageLoadingPreview() = PreviewSurface(dark = true) {
    PlayerPage(
        PlayerPageItem.preview.copy(progress = ListeningProgress(0.0, 0.0, emptyList()), isPlaying = false, isLoading = true),
    ) {}
}

@Preview(showBackground = true, heightDp = 800)
@Composable
private fun PlayerPageSleepPreview() = PreviewSurface(dark = true) { PlayerPage(PlayerPageItem.preview.copy(sleepMinutes = 20)) {} }
