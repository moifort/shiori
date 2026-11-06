package com.polyforms.shiori.shared.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.components.atoms.AudiobookBadge
import com.polyforms.shiori.shared.components.styles.Shiori
import kotlin.math.max
import kotlin.math.min

/** A hue drawn from the title, stable across launches: the placeholder's colour. */
private val Book.coverHue: Float
    get() {
        var hash = 5381UL
        for (scalar in title.codePoints()) hash = hash * 33UL + scalar.toULong()
        return (hash % 360UL).toFloat()
    }

val Book.coverTint: Color get() = Color.hsv(coverHue, 0.45f, 0.55f)

fun Book.coverGround(dark: Boolean): Color {
    val hue = (coverHue + 30f) % 360f
    return if (dark) Color.hsv(hue, 0.5f, 0.3f) else Color.hsv(hue, 0.42f, 0.42f)
}

/**
 * A book's cover at a width, 2:3, rounded in proportion; the typographic placeholder when there
 * is no cover or it fails to load. A recording wears the headphones badge.
 */
@Composable
fun BookCover(
    book: Book,
    width: Dp = 56.dp,
    modifier: Modifier = Modifier,
    showsFormatBadge: Boolean = true,
    formatBadgeSize: Dp? = null,
    coverOpacity: Float = 1f,
    minHeight: Dp? = null,
    cornerRadius: Dp? = null,
    showsPlaceholderAuthor: Boolean = true,
    isBound: Boolean = false,
) {
    val height = max(width.value * 1.5f, minHeight?.value ?: 0f).dp
    val radius = cornerRadius ?: (width * if (isBound) 0.02f else 0.07f)
    val shape = RoundedCornerShape(radius)
    val colors = Shiori.colors
    Box(modifier.size(width, height)) {
        Box(
            Modifier
                .fillMaxSize()
                .alpha(coverOpacity)
                .clip(shape)
                .border(0.5.dp, colors.separator, shape),
        ) {
            val url = book.coverURL
            if (url != null) {
                CoverImage(
                    url,
                    Modifier.fillMaxSize(),
                    loading = { Box(Modifier.fillMaxSize().background(colors.quaternaryLabel)) },
                    fallback = { CoverPlaceholder(book, width, showsPlaceholderAuthor) },
                )
            } else {
                CoverPlaceholder(book, width, showsPlaceholderAuthor)
            }
            if (isBound) BindingRelief()
        }
        if (showsFormatBadge && book.format == BookFormat.AUDIOBOOK) {
            val size = formatBadgeSize ?: max(16f, width.value * 0.32f).dp
            Box(Modifier.align(Alignment.TopEnd).offset(x = size * 0.3f, y = -size * 0.3f).zIndex(1f)) {
                AudiobookBadge(size)
            }
        }
    }
}

@Composable
private fun CoverPlaceholder(book: Book, width: Dp, showsAuthor: Boolean) {
    val authorLine = book.authors.joinToString(", ")
    val density = LocalDensity.current
    fun fitted(text: String, largest: Float, smallest: Float, longWordFloor: Float, shrink: Float): Float {
        val byLength = min(largest, max(smallest, largest - shrink * text.length))
        val longest = text.split(" ").maxOfOrNull { it.length }?.coerceAtLeast(1) ?: 1
        val byWord = width.value * 0.84f / (longest * 0.62f)
        return min(width.value * byLength, max(byWord, width.value * longWordFloor))
    }
    val titleSize = with(density) { fitted(book.title, 0.22f, 0.155f, 0.12f, 0.0046f).dp.toSp() }
    val authorSize = with(density) { fitted(authorLine, 0.13f, 0.105f, 0.09f, 0.001f).dp.toSp() }
    Box(
        Modifier.fillMaxSize().background(
            Brush.linearGradient(listOf(book.coverTint, book.coverTint.copy(alpha = 0.65f))),
        ),
    ) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = width * 0.08f, vertical = width * 0.12f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(width * 0.06f),
        ) {
            Text(
                book.title,
                style = TextStyle(fontSize = titleSize, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Serif, color = Color.White, lineHeight = titleSize * 1.1f),
                textAlign = TextAlign.Center,
                maxLines = 8,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.weight(1f))
            if (showsAuthor && authorLine.isNotEmpty()) {
                Text(
                    authorLine,
                    style = TextStyle(
                        fontSize = authorSize,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Serif,
                        color = Color.White,
                        shadow = Shadow(Color.Black.copy(alpha = 0.3f), Offset(0f, 1f), 2f),
                    ),
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** The hinge pressed into a paperback's front board, at its left edge. */
@Composable
private fun BindingRelief() {
    Box(
        Modifier.fillMaxSize().background(
            Brush.horizontalGradient(
                0f to Color.Black.copy(alpha = 0.42f),
                0.012f to Color.Black.copy(alpha = 0.12f),
                0.022f to Color.White.copy(alpha = 0.28f),
                0.036f to Color.White.copy(alpha = 0.06f),
                0.05f to Color.Black.copy(alpha = 0.26f),
                0.075f to Color.Black.copy(alpha = 0.06f),
                0.11f to Color.White.copy(alpha = 0.08f),
                0.3f to Color.Transparent,
                0.94f to Color.Transparent,
                1f to Color.Black.copy(alpha = 0.12f),
            ),
        ),
    )
}
