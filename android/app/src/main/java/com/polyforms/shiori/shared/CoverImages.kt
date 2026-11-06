package com.polyforms.shiori.shared

import android.os.Build
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImagePainter
import coil3.compose.rememberAsyncImagePainter
import coil3.request.ImageRequest
import coil3.size.Size
import java.net.URI

/**
 * Covers, cached on disk and in memory by Coil. A signed Storage URL is keyed without its
 * `X-Goog-*` signature, which changes on every answer for the same image.
 */
object CoverImages {
    fun key(url: String): String = runCatching {
        val uri = URI(url)
        val kept = uri.rawQuery?.split("&")?.filterNot { it.lowercase().startsWith("x-goog-") }
        val query = kept?.takeIf { it.isNotEmpty() }?.joinToString("&")
        URI(uri.scheme, uri.rawAuthority, uri.rawPath, null, null).toString() + (query?.let { "?$it" } ?: "")
    }.getOrDefault(url)
}

/** The largest side a list decodes covers at, as iOS's `coverMaxPixelSize`. */
val LocalCoverMaxPixelSize = staticCompositionLocalOf<Int?> { null }

/**
 * A cover drawn filling its frame, with a placeholder while it loads and a fallback when it
 * cannot.
 */
@Composable
fun CoverImage(
    url: String,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    loading: @Composable () -> Unit = {},
    fallback: @Composable () -> Unit = {},
) {
    val context = LocalContext.current
    val maxPixels = LocalCoverMaxPixelSize.current
    val key = CoverImages.key(url)
    val request = remember(key, maxPixels) {
        ImageRequest.Builder(context)
            .data(url)
            .memoryCacheKey("$key@${maxPixels ?: 0}")
            .diskCacheKey(key)
            .apply { if (maxPixels != null) size(Size(maxPixels, maxPixels)) }
            .build()
    }
    val painter = rememberAsyncImagePainter(request)
    val state by painter.state.collectAsState()
    Box(modifier) {
        when (state) {
            is AsyncImagePainter.State.Success ->
                Image(painter, null, Modifier.matchParentSize(), contentScale = contentScale)
            is AsyncImagePainter.State.Error -> fallback()
            else -> {
                loading()
                Image(painter, null, Modifier.matchParentSize(), contentScale = contentScale)
            }
        }
    }
}

/** What a cover is turned into behind a page: a blurred wash, or a melt that fades upwards. */
sealed interface CoverEffect {
    data object Backdrop : CoverEffect
    data class Melt(val blur: Int, val fadeStart: Double, val fadeEnd: Double, val dimming: Double) : CoverEffect
}

/** A cover drawn through an effect, filling its frame. */
@Composable
fun CoverEffectImage(url: String, effect: CoverEffect, modifier: Modifier = Modifier, fallback: @Composable () -> Unit = {}) {
    var failed by remember(url) { mutableStateOf(false) }
    if (failed) {
        Box(modifier) { fallback() }
        return
    }
    val context = LocalContext.current
    val key = CoverImages.key(url)
    val request = remember(key) {
        ImageRequest.Builder(context).data(url).memoryCacheKey("$key@effect").diskCacheKey(key)
            .size(Size(240, 240)).build()
    }
    val painter = rememberAsyncImagePainter(request, onError = { failed = true })
    val saturate = remember { ColorMatrix().apply { setToSaturation(1.5f) } }
    when (effect) {
        CoverEffect.Backdrop -> Image(
            painter,
            null,
            modifier.blurCompat(24),
            contentScale = ContentScale.Crop,
            colorFilter = ColorFilter.colorMatrix(saturate),
        )
        is CoverEffect.Melt -> Image(
            painter,
            null,
            modifier
                .blurCompat(effect.blur)
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent {
                    drawContent()
                    drawRect(Color.Black.copy(alpha = effect.dimming.toFloat()))
                    drawRect(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            (1 - effect.fadeStart).toFloat().coerceIn(0f, 1f) to Color.Transparent,
                            (1 - effect.fadeEnd).toFloat().coerceIn(0f, 1f) to Color.Black,
                            1f to Color.Black,
                        ),
                        blendMode = BlendMode.DstIn,
                    )
                },
            contentScale = ContentScale.Crop,
        )
    }
}

/** A blur where the platform draws one (Android 12 and up); a plain image below. */
fun Modifier.blurCompat(radius: Int): Modifier =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) blur(radius.dp) else this
