package com.polyforms.shiori.features.listening

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.listening.components.organisms.PlayerArtwork
import com.polyforms.shiori.features.listening.components.pages.LocalPlayerArtworkFrame
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Closes the player the way a pull-down does: down to the foot of the screen, then into its
 * pill. Null outside the player.
 */
val LocalClosePlayer = compositionLocalOf<(() -> Unit)?> { null }

/** The fixed points of the sheet's trip, in the root's pixels. */
internal data class PlayerSheetGeometry(
    val screen: Size,
    val top: Float,
    val pill: Rect,
    /** The big cover with the sheet open and still; empty before it is measured. */
    val artwork: Rect,
) {
    val sheetHeight: Float get() = screen.height - top

    /**
     * The pull that brings the big cover down level with the pill, from where it draws itself
     * into it; the sheet's top when it is not measured.
     */
    val pullToPill: Float get() = max(0f, pill.top - (if (artwork.isEmpty) top else artwork.top))

    /** The pill's round cover, at its leading end. */
    val pillCover: Rect get() = Rect(pill.left, pill.top, pill.left + pill.height, pill.bottom)
}

/**
 * The full-screen player's own sheet, in place of the system's, as in Music: pulled down by its
 * tab or anywhere on it, it follows the thumb whole, without shrinking; let go far enough, it
 * slides down to the pill and draws itself in around its cover, which flies into the pill's round
 * cover while the sheet narrows and rounds into the pill's glass. Opening runs the same way back,
 * out of the pill.
 *
 * `pillFrame` is the pill's frame in the root. The content is laid out at the sheet's full size
 * whatever the animation does, so nothing reflows.
 */
@Composable
fun PlayerSheet(
    pillFrame: Rect,
    coverURL: String?,
    /** Called once the sheet has gone back into its pill. */
    onClosed: () -> Unit,
    backdrop: @Composable () -> Unit,
    pill: @Composable () -> Unit,
    content: @Composable () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    // 1 in the pill, 0 open.
    val morph = remember { Animatable(1f) }
    // How far the thumb has pulled the sheet down.
    val pull = remember { Animatable(0f) }
    var isClosing by remember { mutableStateOf(false) }
    // The big cover, measured while the sheet is open and still.
    var artworkFrame by remember { mutableStateOf(Rect.Zero) }
    var origin by remember { mutableStateOf(Offset.Zero) }

    BoxWithConstraints(Modifier.fillMaxSize().onGloballyPositioned { origin = it.positionInRoot() }) {
        val screen = Size(constraints.maxWidth.toFloat(), constraints.maxHeight.toFloat())
        val bottomInset = WindowInsets.navigationBars.getBottom(density)
        val top = WindowInsets.statusBars.getTop(density) + with(density) { 8.dp.toPx() }
        val geometry = PlayerSheetGeometry(
            screen = screen,
            top = top,
            // Where a pill sits over the tab bar when none is drawn.
            pill = if (pillFrame.isEmpty) {
                with(density) {
                    Rect(Offset(20.dp.toPx(), screen.height - bottomInset - 140.dp.toPx()), Size(screen.width - 40.dp.toPx(), 56.dp.toPx()))
                }
            } else {
                pillFrame.translate(-origin.x, -origin.y)
            },
            artwork = if (artworkFrame.isEmpty) Rect.Zero else artworkFrame.translate(-origin.x, -origin.y),
        )

        // Down to the pill, then into it.
        fun close() {
            if (isClosing) return
            isClosing = true
            scope.launch {
                pull.animateTo(max(pull.value, geometry.pullToPill), tween(200, easing = FastOutLinearInEasing))
                morph.animateTo(1f, spring(dampingRatio = 0.9f, stiffness = 220f))
                onClosed()
            }
        }
        BackHandler { close() }
        LaunchedEffect(Unit) { morph.animateTo(0f, spring(dampingRatio = 0.85f, stiffness = 180f)) }

        // The spring runs a little past its ends: what is drawn stays between them.
        val m = morph.value.coerceIn(0f, 1f)
        val eased = 1 - (1 - m) * (1 - m)
        val isInteractive = m == 0f && !isClosing
        val sheet = Rect(0f, geometry.top + pull.value, screen.width, geometry.top + pull.value + geometry.sheetHeight)
        // The sheet narrows on the way in a little ahead of the cover, so the cover is never cut
        // by its edges.
        val frame = lerp(sheet, geometry.pill, eased)
        val radius = with(density) { mix(38.dp.toPx(), geometry.pill.height / 2, eased).toDp() }
        val shape = RoundedCornerShape(topStart = radius, topEnd = radius, bottomStart = radius * eased, bottomEnd = radius * eased)

        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f * (1 - m) * max(0f, 1 - pull.value / geometry.sheetHeight))))

        // Down only, from the tab or anywhere on the sheet: it follows the thumb whole. Let go
        // past a quarter of the screen, or flicked, it closes; short of that it climbs back.
        val pullDown = Modifier.draggable(
            rememberDraggableState { delta -> if (isInteractive) scope.launch { pull.snapTo(max(0f, pull.value + delta)) } },
            Orientation.Vertical,
            enabled = isInteractive,
            onDragStopped = { velocity ->
                if (pull.value > geometry.sheetHeight / 4 || pull.value + velocity * 0.2f > geometry.sheetHeight / 2) {
                    close()
                } else {
                    pull.animateTo(0f, spring(dampingRatio = 0.8f, stiffness = 300f))
                }
            },
        )
        Box(
            Modifier
                .offset { IntOffset(frame.left.roundToInt(), frame.top.roundToInt()) }
                .size(with(density) { frame.width.toDp() }, with(density) { frame.height.toDp() })
                .shadow((20 * (1 - m)).dp, shape)
                .clip(shape)
                .then(pullDown),
        ) {
            Box(Modifier.fillMaxSize().alpha(fade(m, 0.55f, 0.95f, out = true))) { backdrop() }
            if (m < 0.25f) {
                Box(
                    Modifier
                        .wrapContentSize(Alignment.TopStart, unbounded = true)
                        .requiredSize(with(density) { screen.width.toDp() }, with(density) { geometry.sheetHeight.toDp() })
                        .graphicsLayer {
                            val scale = frame.width / screen.width
                            scaleX = scale
                            scaleY = scale
                            transformOrigin = TransformOrigin(0f, 0f)
                            alpha = fade(m, 0f, 0.25f, out = true)
                        }
                        .padding(bottom = with(density) { bottomInset.toDp() }),
                ) {
                    CompositionLocalProvider(
                        LocalClosePlayer provides ::close,
                        // Only the cover at rest: the sheet moves it while it slides.
                        LocalPlayerArtworkFrame provides { rect ->
                            if (morph.value == 0f && pull.value == 0f && !isClosing && !rect.isEmpty) artworkFrame = rect
                        },
                    ) { content() }
                }
                Box(
                    Modifier.fillMaxSize().alpha(fade(m, 0f, 0.15f, out = true)).clearAndSetSemantics {},
                    contentAlignment = Alignment.TopCenter,
                ) {
                    Box(Modifier.padding(top = 6.dp).size(36.dp, 5.dp).background(Color.White.copy(alpha = 0.5f), CircleShape))
                }
            }
            if (m > 0.6f) {
                Box(
                    Modifier
                        .wrapContentSize(Alignment.TopStart, unbounded = true)
                        .requiredSize(with(density) { geometry.pill.width.toDp() }, with(density) { geometry.pill.height.toDp() })
                        .alpha(fade(m, 0.6f, 1f, out = false))
                        .clearAndSetSemantics {},
                ) { pill() }
            }
        }

        // The big cover, lifted off the sheet: it flies from its place on the sheet into the
        // pill's round cover, rounding on the way.
        if (!geometry.artwork.isEmpty && m > 0f) {
            val start = geometry.artwork.translate(0f, pull.value)
            val rect = lerp(start, geometry.pillCover, m)
            val side = with(density) { start.width.toDp() }
            val scale = rect.width / start.width
            PlayerArtwork(
                coverURL,
                side,
                Modifier
                    .offset { IntOffset(rect.left.roundToInt(), rect.top.roundToInt()) }
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        transformOrigin = TransformOrigin(0f, 0f)
                        alpha = fade(m, 0.9f, 1f, out = true)
                    },
                cornerRadius = with(density) { mix(12.dp.toPx(), start.width / 2, eased).toDp() },
            )
        }
    }
}

private fun mix(from: Float, to: Float, t: Float) = from + (to - from) * t

private fun lerp(from: Rect, to: Rect, t: Float) =
    Rect(mix(from.left, to.left, t), mix(from.top, to.top, t), mix(from.right, to.right, t), mix(from.bottom, to.bottom, t))

/** An opacity along the morph: fading out between `from` and `to`, or in. */
private fun fade(t: Float, from: Float, to: Float, out: Boolean): Float {
    val progress = ((t - from) / (to - from)).coerceIn(0f, 1f)
    return if (out) 1 - progress else progress
}
