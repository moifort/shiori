package com.polyforms.shiori.shared.shell

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.withFrameNanos
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.glass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.ceil
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * The launch covers bundled with the app, decoded once per process off the main thread: cut to
 * a cover's shape at its size on screen, corners rounded, uploaded to the GPU. Started from
 * `ShioriApplication`, so they are usually ready by the first frame; until then the list is
 * empty and the drift fades them in when they arrive, as on iOS.
 */
object LaunchCovers {
    private val decoded = MutableStateFlow<List<Bitmap>>(emptyList())

    /** The covers decoded so far: empty until all of them are ready. */
    val bitmaps: List<Bitmap> get() = decoded.value
    private val started = AtomicBoolean(false)

    /** Starts decoding, once; later calls do nothing. */
    fun preload(context: Context) {
        if (!started.compareAndSet(false, true)) return
        val app = context.applicationContext
        CoroutineScope(Dispatchers.Default).launch {
            val files = coverFiles(app)
            val chunks = files.chunked(maxOf(1, (files.size + 3) / 4))
            decoded.value = chunks
                .map { chunk -> async { chunk.mapNotNull { coverImage(app, it) } } }
                .awaitAll()
                .flatten()
                .shuffled()
        }
    }

    @Composable
    fun current(): List<ImageBitmap> {
        val context = LocalContext.current
        preload(context)
        val bitmaps = decoded.collectAsState().value
        return remember(bitmaps) { bitmaps.map { it.asImageBitmap() } }
    }

    /**
     * Every `launch-cover-*.jpg` in the assets, like the iOS bundle's files. Assets rather than
     * drawables: a release build shortens resource names, so a drawable looked up by its name
     * is never found there, and the curtain stayed bare.
     */
    private fun coverFiles(context: Context): List<String> =
        context.assets.list(COVERS_FOLDER).orEmpty().filter { it.startsWith("launch-cover-") }.map { "$COVERS_FOLDER/$it" }

    /** The cover filling `COVER_W` × `COVER_H` dp, cropped from its centre, corners rounded. */
    private fun coverImage(context: Context, file: String): Bitmap? {
        val source = runCatching { context.assets.open(file).use { BitmapFactory.decodeStream(it) } }.getOrNull() ?: return null
        val density = context.resources.displayMetrics.density
        val width = (COVER_W * density).roundToInt()
        val height = (COVER_H * density).roundToInt()
        val scale = maxOf(width / source.width.toFloat(), height / source.height.toFloat())
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((width - source.width * scale) / 2f, (height - source.height * scale) / 2f)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(matrix) }
        }
        val radius = COVER_RADIUS * density
        val cover = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(cover).drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
        source.recycle()
        val uploaded = cover.copy(Bitmap.Config.HARDWARE, false) ?: return cover
        cover.recycle()
        return uploaded
    }
}

internal const val COVER_W = 96f
internal const val COVER_H = 146f
internal const val COVER_SPACING = 14f
private const val COVER_RADIUS = 5f
private const val COVERS_FOLDER = "launch-covers"

/** A row's pace in dp per second: each runs a little faster or slower than 26. */
internal fun drivePace(row: Int) = 26f * (0.8f + 0.4f * ((row * 7) % 5) / 4f)

/** The launch covers, shuffled once per launch; empty until decoded. */
@Composable
fun rememberLaunchCovers(): List<ImageBitmap> = LaunchCovers.current()

/**
 * Covers drifting in rows across a band tilted by twelve degrees, every other row the other
 * way: the wall behind the sign-in and the launch.
 *
 * Each row is drawn once into its layer and only moved afterwards: the clock is read in the
 * layer's translation, so a frame costs neither a recomposition nor a redraw, and the drift
 * keeps its pace while the app is busy starting.
 */
@Composable
fun CoverDrift(covers: List<ImageBitmap>, moving: Boolean = true, modifier: Modifier = Modifier) {
    val appear = remember { Animatable(0f) }
    LaunchedEffect(covers.isNotEmpty()) {
        if (covers.isNotEmpty()) appear.animateTo(1f, tween(800, easing = LinearOutSlowInEasing))
    }
    if (covers.isEmpty()) return
    val seconds = remember { mutableFloatStateOf(0f) }
    if (moving) {
        LaunchedEffect(Unit) {
            val origin = withFrameNanos { it }
            while (true) withFrameNanos { seconds.floatValue = (it - origin) / 1e9f }
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().graphicsLayer { alpha = appear.value }) {
        val w = maxWidth.value
        val h = maxHeight.value
        val diagonal = sqrt(w * w + h * h)
        val spacing = COVER_SPACING
        val pitch = COVER_H + spacing
        val step = COVER_W + spacing
        val rowCount = ceil(diagonal / pitch).toInt() + 1
        val across = ceil(diagonal / step).toInt() + 1
        val hands = (0 until minOf(rowCount, covers.size)).map { hand -> covers.indices.filter { it % minOf(rowCount, covers.size) == hand }.map { covers[it] } }
        Box(
            Modifier
                .requiredSize(diagonal.dp, (rowCount * pitch).dp)
                .align(Alignment.Center)
                .rotate(-12f),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(spacing.dp)) {
                repeat(rowCount) { row ->
                    val hand = hands[row % hands.size]
                    val perStrip = hand.size * ceil(across.toFloat() / hand.size).toInt()
                    val repeatWidth = perStrip * step
                    val pace = drivePace(row)
                    val leftward = row % 2 == 0
                    val count = perStrip + across
                    // The strip is wider than the band: measured unbounded, or Compose squeezes
                    // it to the band's width and the rows sliding right, which start a whole
                    // repeat to the left, show no cover at all.
                    Spacer(
                        Modifier
                            .wrapContentWidth(Alignment.Start, unbounded = true)
                            .size((count * step - spacing).dp, COVER_H.dp)
                            .graphicsLayer {
                                val progress = (seconds.floatValue * pace / repeatWidth) % 1f
                                val shift = if (leftward) -progress * repeatWidth else -repeatWidth + progress * repeatWidth
                                translationX = shift.dp.toPx()
                            }
                            .drawWithCache {
                                val stride = step.dp.toPx()
                                onDrawBehind {
                                    repeat(count) { index -> drawImage(hand[index % hand.size], Offset(index * stride, 0f)) }
                                }
                            },
                    )
                }
            }
        }
    }
}

/** The drifting covers on black, behind the sign-in, the onboarding and the preparation. */
@Composable
fun CoverWall() {
    val covers = rememberLaunchCovers()
    Box(Modifier.fillMaxSize().background(Color.Black)) { CoverDrift(covers) }
}

/** A frosted veil over the wall, rising from the bottom; full when `covering`. */
@Composable
fun CoverVeil(covering: Boolean = false) {
    val veil = Color(0xE61C1C1E)
    Box(
        Modifier.fillMaxSize().background(
            if (covering) Brush.verticalGradient(listOf(veil, veil))
            else Brush.verticalGradient(0.46f to Color.Transparent, 0.64f to veil, 1f to veil),
        ),
    )
}

/** A spinner and a line in a glass capsule: the library being prepared. */
@Composable
fun OpeningProgress(label: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).height(52.dp).clip(CircleShape).glass(CircleShape),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = Shiori.colors.label)
        Text(label, style = Shiori.type.body.copy(fontWeight = FontWeight.SemiBold), color = Shiori.colors.label)
    }
}
