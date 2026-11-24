package com.polyforms.shiori.shared

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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.platform.LocalContext
import coil3.compose.AsyncImagePainter
import coil3.compose.rememberAsyncImagePainter
import coil3.compose.rememberConstraintsSizeResolver
import coil3.request.crossfade
import coil3.request.transformations
import coil3.request.ImageRequest
import coil3.size.Size
import java.net.URI
import kotlin.math.roundToInt

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
 * cannot. It is decoded at the size of its frame, never at the file's own: a full-size bitmap
 * per cover costs memory, and an upload to the GPU on the frame it first shows.
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
    val frame = rememberConstraintsSizeResolver()
    val request = remember(key, maxPixels, frame) {
        ImageRequest.Builder(context)
            .data(url)
            .memoryCacheKey("$key@${maxPixels ?: 0}")
            .diskCacheKey(key)
            .apply { if (maxPixels != null) size(Size(maxPixels, maxPixels)) else size(frame) }
            .build()
    }
    val painter = rememberAsyncImagePainter(request)
    val state by painter.state.collectAsState()
    Box(modifier.then(frame)) {
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

    /** `blur` is in dp of the frame; the fade runs from `fadeStart` to `fadeEnd` of its height. */
    data class Melt(val blur: Int, val fadeStart: Double, val fadeEnd: Double, val dimming: Double) : CoverEffect
}

/**
 * A cover drawn through an effect, filling its frame. The effect is computed once, off the main
 * thread, and kept in memory (`CoverEffectTransformation`): a live blur on each cover of a
 * scrolled page is paid on every frame, which is what made the iOS home lag on 2026-11-01.
 */
@Composable
fun CoverEffectImage(url: String, effect: CoverEffect, modifier: Modifier = Modifier, fallback: @Composable () -> Unit = {}) {
    var failed by remember(url) { mutableStateOf(false) }
    if (failed) {
        Box(modifier) { fallback() }
        return
    }
    val context = LocalContext.current
    val key = CoverImages.key(url)
    // A melt is baked for the frame it is drawn in, a dp to a pixel; a wash fits any frame.
    var canvas by remember { mutableStateOf(if (effect is CoverEffect.Melt) IntSize.Zero else IntSize(1, 1)) }
    val density = LocalDensity.current
    val measured = if (effect is CoverEffect.Melt) {
        Modifier.onSizeChanged { size ->
            val next = with(density) { IntSize(size.width.toDp().value.roundToInt(), size.height.toDp().value.roundToInt()) }
            if (next != canvas) canvas = next
        }
    } else {
        Modifier
    }
    val painter = if (canvas == IntSize.Zero) {
        null
    } else {
        val request = remember(key, effect, canvas) {
            val transformation = CoverEffectTransformation(effect, canvas.width, canvas.height)
            // The source: iOS's 120 pixels for a wash, half as much again as the frame for a melt.
            val source = if (effect is CoverEffect.Melt) maxOf(canvas.width, canvas.height) * 3 / 2 else 120
            ImageRequest.Builder(context)
                .data(url)
                .memoryCacheKey("$key@${transformation.cacheKey}")
                .diskCacheKey(key)
                .size(Size(source, source))
                .transformations(transformation)
                .crossfade(false)
                .build()
        }
        rememberAsyncImagePainter(request, onError = { failed = true })
    }
    Box(modifier.then(measured)) {
        if (painter != null) {
            Image(
                painter,
                null,
                Modifier.matchParentSize(),
                contentScale = if (effect is CoverEffect.Melt) ContentScale.FillBounds else ContentScale.Crop,
            )
        }
    }
}
