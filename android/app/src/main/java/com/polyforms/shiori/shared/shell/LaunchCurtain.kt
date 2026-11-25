package com.polyforms.shiori.shared.shell

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.view.Choreographer
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.polyforms.shiori.R
import kotlinx.coroutines.delay
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * The launch: the app's icon rising over the drifting covers.
 *
 * Drawn on its own surface by its own thread, like the iOS curtain whose rows Core Animation
 * moves: the app composes its first screen behind it on the main thread, and the curtain keeps
 * its pace meanwhile. `fading` starts the fade out; `onFaded` follows once it is transparent.
 */
@Composable
fun LaunchCurtain(fading: Boolean = false, onFaded: () -> Unit = {}) {
    val context = LocalContext.current
    LaunchCovers.preload(context)
    // Black under the surface until it shows its first frame, so the screen behind never
    // flashes through; gone once the fade begins, so the fade reveals it.
    Box(Modifier.fillMaxSize().background(if (fading) Color.Transparent else Color.Black)) {
        AndroidView(
            factory = { LaunchCurtainView(it) },
            modifier = Modifier.fillMaxSize(),
            update = { if (fading) it.fadeOut(onFaded) },
        )
    }
}

/** The curtain over the app until it is ready, shown at least two seconds, then faded. */
@Composable
fun LaunchCurtainHost(ready: Boolean, content: @Composable () -> Unit) {
    var entranceOver by remember { mutableStateOf(false) }
    var gone by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(2000)
        entranceOver = true
    }
    Box(Modifier.fillMaxSize()) {
        content()
        if (!gone) LaunchCurtain(fading = ready && entranceOver, onFaded = { gone = true })
    }
}

/**
 * The curtain's surface. Its thread draws every frame from the clock alone: the covers
 * drifting in rows tilted by twelve degrees, every other row the other way, a dark halo, the
 * icon springing in, then the fade.
 */
private class LaunchCurtainView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    private val density = resources.displayMetrics.density
    private val icon = iconBitmap(context, (140 * density).toInt())
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.BLACK
        setShadowLayer(14 * density, 0f, 6 * density, AndroidColor.argb(110, 0, 0, 0))
    }
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var width = 0
    private var height = 0
    private var halo: Paint? = null

    // Read and written on the curtain's thread only, apart from the fade request.
    private var origin = 0L
    private var coversSince = 0L
    private var covers: List<Bitmap> = emptyList()
    private var hands: List<List<Bitmap>> = emptyList()
    private val slot = RectF()
    @Volatile private var fadeRequested: (() -> Unit)? = null
    private var fadeSince = 0L
    private var faded = false

    init {
        setZOrderOnTop(true)
        holder.setFormat(PixelFormat.TRANSLUCENT)
        holder.addCallback(this)
        contentDescription = "Shiori"
    }

    fun fadeOut(onFaded: () -> Unit) {
        if (fadeRequested == null) fadeRequested = onFaded
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        val thread = HandlerThread("launch-curtain", Process.THREAD_PRIORITY_DISPLAY).also { it.start() }
        this.thread = thread
        handler = Handler(thread.looper).also { it.post { Choreographer.getInstance().postFrameCallback(frame) } }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        handler?.post {
            this.width = width
            this.height = height
            halo = Paint().apply {
                shader = RadialGradient(
                    width / 2f, height / 2f, 200 * density,
                    intArrayOf(AndroidColor.argb(179, 0, 0, 0), AndroidColor.argb(102, 0, 0, 0), AndroidColor.TRANSPARENT),
                    null, Shader.TileMode.CLAMP,
                )
            }
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        val handler = handler ?: return
        val stopped = CountDownLatch(1)
        handler.post {
            Choreographer.getInstance().removeFrameCallback(frame)
            stopped.countDown()
        }
        stopped.await(500, TimeUnit.MILLISECONDS)
        thread?.quitSafely()
        thread = null
        this.handler = null
    }

    private val frame = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (faded) return
            Choreographer.getInstance().postFrameCallback(this)
            if (width == 0) return
            if (origin == 0L) origin = frameTimeNanos
            if (covers.isEmpty()) {
                covers = LaunchCovers.bitmaps
                if (covers.isNotEmpty()) coversSince = frameTimeNanos
            }
            val onFaded = fadeRequested
            if (onFaded != null && fadeSince == 0L) fadeSince = frameTimeNanos
            val fade = if (fadeSince == 0L) 1f else 1f - ((frameTimeNanos - fadeSince) / 700e6f).coerceIn(0f, 1f)
            val canvas = try {
                holder.lockHardwareCanvas()
            } catch (_: IllegalStateException) {
                null
            } ?: return
            try {
                draw(canvas, frameTimeNanos, fade)
            } finally {
                holder.unlockCanvasAndPost(canvas)
            }
            if (fade <= 0f) {
                faded = true
                if (onFaded != null) Handler(Looper.getMainLooper()).post(onFaded)
            }
        }
    }

    private fun draw(canvas: Canvas, now: Long, fade: Float) {
        canvas.drawColor(AndroidColor.TRANSPARENT, PorterDuff.Mode.CLEAR)
        if (fade <= 0f) return
        val layered = fade < 1f
        if (layered) canvas.saveLayerAlpha(0f, 0f, width.toFloat(), height.toFloat(), (fade * 255).toInt())
        canvas.drawColor(AndroidColor.BLACK)
        drawCovers(canvas, now)
        halo?.let { canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), it) }
        drawIcon(canvas, (now - origin) / 1e9f)
        if (layered) canvas.restore()
    }

    /** The same rows as `CoverDrift`, faded in over 0.8 s once the covers are decoded. */
    private fun drawCovers(canvas: Canvas, now: Long) {
        if (covers.isEmpty()) return
        val appear = ((now - coversSince) / 800e6f).coerceIn(0f, 1f)
        paint.alpha = ((1f - (1f - appear) * (1f - appear)) * 255).toInt()
        val seconds = (now - coversSince) / 1e9f
        val w = width / density
        val h = height / density
        val diagonal = sqrt(w * w + h * h)
        val pitch = COVER_H + COVER_SPACING
        val step = COVER_W + COVER_SPACING
        val rowCount = ceil(diagonal / pitch).toInt() + 1
        val across = ceil(diagonal / step).toInt() + 1
        if (hands.isEmpty()) {
            val count = minOf(rowCount, covers.size)
            hands = (0 until count).map { hand -> covers.filterIndexed { index, _ -> index % count == hand } }
        }
        canvas.save()
        canvas.translate(width / 2f, height / 2f)
        canvas.rotate(-12f)
        canvas.scale(density, density)
        canvas.translate(-diagonal / 2f, -rowCount * pitch / 2f)
        for (row in 0 until rowCount) {
            val hand = hands[row % hands.size]
            val perStrip = hand.size * ceil(across.toFloat() / hand.size).toInt()
            val repeatWidth = perStrip * step
            val progress = (seconds * drivePace(row) / repeatWidth) % 1f
            val shift = if (row % 2 == 0) -progress * repeatWidth else -repeatWidth + progress * repeatWidth
            val first = maxOf(0, ((-shift) / step).toInt() - 1)
            val last = minOf(perStrip + across - 1, ((diagonal - shift) / step).toInt() + 1)
            canvas.save()
            canvas.translate(shift, row * pitch)
            for (index in first..last) {
                slot.set(index * step, 0f, index * step + COVER_W, COVER_H)
                canvas.drawBitmap(hand[index % hand.size], null, slot, paint)
            }
            canvas.restore()
        }
        canvas.restore()
    }

    /** The icon springing in like Compose's spring(dampingRatio 0.7, stiffness 110). */
    private fun drawIcon(canvas: Canvas, seconds: Float) {
        val omega = sqrt(110f)
        val zeta = 0.7f
        val damped = omega * sqrt(1 - zeta * zeta)
        val value = 1f - exp(-zeta * omega * seconds) * (cos(damped * seconds) + zeta * omega / damped * sin(damped * seconds))
        val alpha = value.coerceIn(0f, 1f)
        if (alpha <= 0f) return
        val scale = 0.8f + 0.2f * value
        val radius = icon.width / 2f
        canvas.save()
        canvas.translate(width / 2f, height / 2f)
        canvas.scale(scale, scale)
        shadow.alpha = (alpha * 255).toInt()
        canvas.drawCircle(0f, 0f, radius, shadow)
        paint.alpha = (alpha * 255).toInt()
        canvas.drawBitmap(icon, -radius, -radius, paint)
        canvas.restore()
    }

    private companion object {
        /**
         * The launcher icon as the Pixel draws it: the adaptive icon's two layers in a circle,
         * the 108 dp canvas scaled so its visible 72 dp fill the disc.
         */
        fun iconBitmap(context: Context, size: Int): Bitmap {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.clipPath(Path().apply { addCircle(size / 2f, size / 2f, size / 2f, Path.Direction.CW) })
            val layer = (size * 1.5f).toInt()
            val inset = (size - layer) / 2
            listOf(R.drawable.ic_launcher_background, R.mipmap.ic_launcher_foreground).forEach { id ->
                ContextCompat.getDrawable(context, id)?.apply {
                    setBounds(inset, inset, inset + layer, inset + layer)
                    draw(canvas)
                }
            }
            return bitmap
        }
    }
}
