package com.polyforms.shiori.shared

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import coil3.size.Size
import coil3.transform.Transformation
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * A cover turned into its effect once, off the main thread, as iOS's `CoverEffect.applied`: the
 * result is drawn as a plain image, so nothing is blurred again on each frame of a scroll.
 */
internal class CoverEffectTransformation(
    private val effect: CoverEffect,
    /** The frame a melt is drawn in, at one pixel a dp: a blur holds no detail to lose. */
    private val canvasWidth: Int,
    private val canvasHeight: Int,
) : Transformation() {
    override val cacheKey: String = "$effect@${canvasWidth}x$canvasHeight"

    override suspend fun transform(input: Bitmap, size: Size): Bitmap = when (effect) {
        CoverEffect.Backdrop -> backdrop(input)
        is CoverEffect.Melt -> melt(input, effect)
    }

    /** A hero's colours: small, blurred and saturated. */
    private fun backdrop(input: Bitmap): Bitmap {
        // Brought down to iOS's 120 pixels whatever was decoded, so the blur is the same wash.
        val scale = BACKDROP_SIDE.toFloat() / max(input.width, input.height)
        val width = max(1, (input.width * scale).roundToInt())
        val height = max(1, (input.height * scale).roundToInt())
        val pixels = drawn(input, width, height)
        gaussianBlur(pixels, width, height, BACKDROP_SIGMA)
        for (index in pixels.indices) pixels[index] = saturated(pixels[index], 1.5f)
        return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
    }

    /** The foot of a cover melting into a blur, transparent above it, along a smoothstep. */
    private fun melt(input: Bitmap, effect: CoverEffect.Melt): Bitmap {
        val width = max(1, canvasWidth)
        val height = max(1, canvasHeight)
        val pixels = drawn(input, width, height)
        gaussianBlur(pixels, width, height, effect.blur.toFloat())
        val keep = (1 - effect.dimming).toFloat().coerceIn(0f, 1f)
        val start = effect.fadeStart.toFloat()
        val span = (effect.fadeEnd - effect.fadeStart).toFloat().coerceAtLeast(0.0001f)
        for (y in 0 until height) {
            val t = (((y + 0.5f) / height - start) / span).coerceIn(0f, 1f)
            val alpha = (t * t * (3 - 2 * t) * 255).roundToInt()
            val row = y * width
            for (x in 0 until width) {
                val pixel = pixels[row + x]
                val r = (((pixel shr 16) and 0xFF) * keep).roundToInt()
                val g = (((pixel shr 8) and 0xFF) * keep).roundToInt()
                val b = ((pixel and 0xFF) * keep).roundToInt()
                pixels[row + x] = (alpha shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply {
            setPixels(pixels, 0, width, 0, 0, width, height)
        }
    }

    /** The cover filling a canvas and centred, as `ContentScale.Crop` draws it, as pixels. */
    private fun drawn(input: Bitmap, width: Int, height: Int): IntArray {
        val canvas = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val scale = max(width.toFloat() / input.width, height.toFloat() / input.height)
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((width - input.width * scale) / 2f, (height - input.height * scale) / 2f)
        }
        Canvas(canvas).drawBitmap(input, matrix, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        val pixels = IntArray(width * height)
        canvas.getPixels(pixels, 0, width, 0, 0, width, height)
        canvas.recycle()
        return pixels
    }

    private fun saturated(pixel: Int, amount: Float): Int {
        val r = (pixel shr 16) and 0xFF
        val g = (pixel shr 8) and 0xFF
        val b = pixel and 0xFF
        val grey = 0.213f * r + 0.715f * g + 0.072f * b
        fun channel(value: Int) = (grey + (value - grey) * amount).roundToInt().coerceIn(0, 255)
        return (0xFF shl 24) or (channel(r) shl 16) or (channel(g) shl 8) or channel(b)
    }

    private companion object {
        const val BACKDROP_SIDE = 120
        const val BACKDROP_SIGMA = 8f

        /**
         * A Gaussian blur of the opaque colours, its edges held as they are (no dark rim): three
         * box blurs, which come within a few percent of the bell.
         */
        fun gaussianBlur(pixels: IntArray, width: Int, height: Int, sigma: Float) {
            if (sigma <= 0f) return
            val channels = Array(3) { IntArray(pixels.size) }
            for (index in pixels.indices) {
                val pixel = pixels[index]
                channels[0][index] = (pixel shr 16) and 0xFF
                channels[1][index] = (pixel shr 8) and 0xFF
                channels[2][index] = pixel and 0xFF
            }
            // Three boxes of the width that gives the bell's variance.
            val ideal = sqrt(12f * sigma * sigma / 3f + 1f)
            var low = ideal.toInt()
            if (low % 2 == 0) low -= 1
            low = max(1, low)
            val high = low + 2
            val lows = ((12f * sigma * sigma - 3f * low * low - 12f * low - 9f) / (-4f * low - 4f)).roundToInt()
            val scratch = IntArray(pixels.size)
            for (channel in channels) {
                for (pass in 0 until 3) {
                    val radius = ((if (pass < lows) low else high) - 1) / 2
                    boxBlur(channel, scratch, width, height, radius, horizontal = true)
                    boxBlur(scratch, channel, width, height, radius, horizontal = false)
                }
            }
            for (index in pixels.indices) {
                pixels[index] = (0xFF shl 24) or (channels[0][index] shl 16) or (channels[1][index] shl 8) or channels[2][index]
            }
        }

        private fun boxBlur(source: IntArray, target: IntArray, width: Int, height: Int, radius: Int, horizontal: Boolean) {
            val length = if (horizontal) width else height
            val lines = if (horizontal) height else width
            val step = if (horizontal) 1 else width
            val window = 2 * radius + 1
            for (line in 0 until lines) {
                val origin = if (horizontal) line * width else line
                var sum = 0
                for (offset in -radius..radius) sum += source[origin + offset.coerceIn(0, length - 1) * step]
                for (position in 0 until length) {
                    target[origin + position * step] = sum / window
                    val leaving = (position - radius).coerceIn(0, length - 1)
                    val entering = (position + radius + 1).coerceIn(0, length - 1)
                    sum += source[origin + entering * step] - source[origin + leaving * step]
                }
            }
        }
    }
}
