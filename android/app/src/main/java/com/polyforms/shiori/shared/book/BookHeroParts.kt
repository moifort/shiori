package com.polyforms.shiori.shared.book

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.CoverEffect
import com.polyforms.shiori.shared.CoverEffectImage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.blurCompat
import com.polyforms.shiori.shared.components.atoms.BookmarkRibbon
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.ProgressBar
import com.polyforms.shiori.shared.components.atoms.StarSymbol
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * A cover blurred into a wash behind a page's head, darkened for white text, fading into the
 * page's ground at its foot.
 */
@Composable
fun CoverBackdrop(
    url: String?,
    modifier: Modifier = Modifier,
    fadeHeight: Dp = 36.dp,
    ground: Color = Shiori.colors.groupedBackground,
    tint: Color? = null,
) {
    Box(modifier.clipToBounds().background(Color(0xFF1F1F1F))) {
        if (url != null) {
            CoverEffectImage(url, CoverEffect.Backdrop, Modifier.fillMaxSize().scale(1.6f).alpha(0.85f)) {
                Box(Modifier.fillMaxSize().background(tint ?: Color.Transparent))
            }
        } else if (tint != null) {
            Box(Modifier.fillMaxSize().background(tint))
        }
        if (url != null || tint == null) {
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.45f), Color.Black.copy(alpha = 0.25f), Color.Black.copy(alpha = 0.4f))),
                ),
            )
        }
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(fadeHeight)
                .background(
                    Brush.verticalGradient(
                        *(0..12).map { step ->
                            val t = step / 12f
                            t to ground.copy(alpha = t * t * (3 - 2 * t))
                        }.toTypedArray(),
                    ),
                ),
        )
    }
}

/** The bar and figure of a recording under way: "6h12 restantes · 42%". */
@Composable
fun ListeningProgressLine(progress: Int, durationMinutes: Int?) {
    val clamped = progress.coerceIn(0, 100)
    val remaining = durationMinutes?.let { total ->
        val left = total * (100 - clamped) / 100
        val hours = left / 60
        val minutes = left % 60
        val label = when {
            hours == 0 -> L("%lldmin", minutes)
            minutes == 0 -> L("%lldh", hours)
            else -> L("%lldh%@", hours, "%02d".format(minutes))
        }
        L("%@ restantes", label)
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        ProgressBar(clamped / 100.0, 56.dp)
        Text(
            remaining?.let { "$it · $clamped%" } ?: L("%lld%% écouté", progress),
            style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
            color = Color.White,
            maxLines = 1,
        )
    }
}

/** "page 214 · 32%", with a bar, which opens the page sheet; a "+12 pages" rises when it grows. */
@Composable
fun ReadingPageLine(page: Int?, pageCount: Int? = null, onOpen: (() -> Unit)? = null) {
    var shown by remember { mutableStateOf(page) }
    var gain by remember { mutableStateOf<Int?>(null) }
    val rise = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(page) {
        val old = shown
        if (page == old) return@LaunchedEffect
        delay(550)
        shown = page
        if (page != null && page > (old ?: 0)) {
            val pages = page - (old ?: 0)
            gain = pages
            scope.launch {
                rise.snapTo(0f)
                rise.animateTo(1f, tween(450))
                delay(1600)
                rise.animateTo(2f, tween(600))
                if (gain == pages) gain = null
            }
        }
    }
    val current = shown ?: return
    val progress = pageCount?.takeIf { it > 0 }?.let { minOf(100, current * 100 / it) }
    Box(if (onOpen != null) Modifier.plainClickable(onClick = onOpen) else Modifier) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            if (progress != null) ProgressBar(progress / 100.0, 56.dp)
            Text(
                if (progress != null) L("page %lld · %lld%%", current, progress) else L("page %lld", current),
                style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
                maxLines = 1,
            )
        }
        gain?.let { pages ->
            val phase = rise.value
            Text(
                L("+%lld pages", pages),
                style = Shiori.type.subheadline.copy(
                    fontWeight = FontWeight.Black,
                    shadow = Shadow(Color.White.copy(alpha = 0.7f), Offset.Zero, 12f),
                ),
                color = Color.White,
                modifier = Modifier
                    .offset(x = if (progress == null) 0.dp else 64.dp, y = (-6 - 18 * minOf(phase, 1f) - 14 * maxOf(0f, phase - 1f)).dp)
                    .graphicsLayer {
                        alpha = if (phase <= 1f) phase else 2f - phase
                        val s = 0.6f + 0.4f * minOf(phase, 1f)
                        scaleX = s
                        scaleY = s
                    },
            )
        }
    }
}


/** A synopsis folded to four lines, with "Plus" to unfold it. */
@Composable
fun BookSynopsisBlock(synopsis: String) {
    var expanded by remember { mutableStateOf(false) }
    var truncated by remember { mutableStateOf(false) }
    val colors = Shiori.colors
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            synopsis,
            style = Shiori.type.callout,
            color = colors.label,
            maxLines = if (expanded) Int.MAX_VALUE else 4,
            overflow = TextOverflow.Ellipsis,
            onTextLayout = { if (!expanded) truncated = it.hasVisualOverflow },
        )
        if (truncated || expanded) {
            Text(
                (if (expanded) L("Moins") else L("Plus")).uppercase(),
                style = Shiori.type.footnote.copy(fontWeight = FontWeight.Bold),
                color = colors.secondaryLabel,
                modifier = Modifier.plainClickable { expanded = !expanded },
            )
        }
    }
}

/**
 * A cover as a poster: dimmed, its foot melted into a blur that carries a white caption, the
 * edition tags at its top right and a bookmark for a book under way.
 */
@Composable
fun PosterCover(
    book: Book,
    caption: String,
    modifier: Modifier = Modifier,
    width: Dp = 102.dp,
    showsEditionTags: Boolean = true,
    captionColor: Color = Color.White,
    dimming: Double = 0.12,
    marksReading: Boolean = false,
    progress: Int? = null,
    rating: Double? = null,
    isGreyed: Boolean = false,
) {
    val shape = RoundedCornerShape(8.dp)
    val grey = remember { ColorMatrix().apply { setToSaturation(0f) } }
    Box(modifier.size(width, width * 1.5f).clip(shape)) {
        Box(Modifier.fillMaxSize().then(if (isGreyed) Modifier.graphicsLayer { } else Modifier)) {
            BookCover(book, width, showsFormatBadge = false, cornerRadius = 8.dp, showsPlaceholderAuthor = false)
        }
        if (isGreyed) Box(Modifier.fillMaxSize().background(Color.Gray.copy(alpha = 0.35f)))
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = dimming.toFloat())))
        val url = book.coverURL
        if (url != null) {
            CoverEffectImage(
                url,
                CoverEffect.Melt(blur = 20, fadeStart = 0.4, fadeEnd = 0.92, dimming = dimming),
                Modifier.fillMaxSize(),
            )
        } else {
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(0.4f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.35f)),
                ),
            )
        }
        if (showsEditionTags) Box(Modifier.align(Alignment.TopEnd).padding(6.dp)) { CoverTags(book) }
        if (marksReading) {
            Box(Modifier.align(Alignment.TopStart).padding(start = if (width < 110.dp) 10.dp else 12.dp)) {
                BookmarkRibbon(if (width < 110.dp) 12.dp else 14.dp)
            }
        }
        Row(
            Modifier.align(Alignment.BottomCenter).padding(start = 6.dp, end = 6.dp, bottom = 9.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (progress != null) ProgressBar(progress / 100.0, if (width < 110.dp) 30.dp else 40.dp)
            val shadow = Shadow(Color.Black.copy(alpha = 0.5f), Offset.Zero, 8f)
            if (rating != null) {
                if (rating >= 5) {
                    Icon(Symbol("heart.fill"), caption, Modifier.size(14.dp), tint = captionColor)
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) {
                        for (star in 1..5) {
                            val symbol = StarSymbol.of(star, rating)
                            Icon(
                                Symbol(symbol.symbol),
                                null,
                                Modifier.size(13.dp).alpha(if (symbol == StarSymbol.EMPTY) 0.7f else 1f),
                                tint = captionColor,
                            )
                        }
                    }
                }
            } else {
                Text(
                    caption,
                    style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold, shadow = shadow),
                    color = captionColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Box(Modifier.fillMaxSize().border(1.dp, Color.White.copy(alpha = 0.22f), shape))
    }
}

@Composable
fun PosterCover(book: Book, label: PosterLabel, modifier: Modifier = Modifier, width: Dp = 102.dp, showsEditionTags: Boolean = true) =
    PosterCover(
        book,
        label.caption,
        modifier,
        width,
        showsEditionTags,
        dimming = label.dimming,
        marksReading = label.marksReading,
        progress = label.progress,
        rating = label.rating,
        isGreyed = label.isGreyed,
    )
