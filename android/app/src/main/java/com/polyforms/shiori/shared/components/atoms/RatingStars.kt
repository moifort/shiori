package com.polyforms.shiori.shared.components.atoms

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import kotlin.math.ceil
import java.text.NumberFormat

enum class StarSymbol(val symbol: String) {
    FULL("star.fill"), HALF("star.leadinghalf.filled"), EMPTY("star");

    companion object {
        fun of(star: Int, rating: Double): StarSymbol = when {
            star <= rating -> FULL
            star - 0.5 <= rating -> HALF
            else -> EMPTY
        }
    }
}

/** "3,5": a rating as words say it, no trailing zero. */
val Double.starsText: String
    get() = NumberFormat.getNumberInstance().apply { maximumFractionDigits = 1; minimumFractionDigits = 0 }.format(this)

/** Five stars, filled to the rating: yellow for the book's own, grey for one lent by its saga. */
@Composable
fun RatingStars(
    rating: Double,
    total: Int = 5,
    size: Dp = 11.dp,
    inherited: Boolean = false,
    monochrome: Boolean = false,
    tint: Color? = null,
) {
    val colors = Shiori.colors
    val filled = tint ?: when {
        monochrome -> colors.label
        inherited -> colors.secondaryLabel
        else -> colors.yellow
    }
    val empty = if (tint != null) tint.copy(alpha = 0.35f) else if (monochrome) colors.label.copy(alpha = 0.35f) else colors.gray.copy(alpha = 0.3f)
    val description = if (inherited) {
        L("Note de la série : %@ sur %lld", rating.starsText, total)
    } else {
        L("Note : %@ sur %lld", rating.starsText, total)
    }
    Row(Modifier.semantics { contentDescription = description }, horizontalArrangement = Arrangement.spacedBy(1.dp)) {
        for (star in 1..total) {
            val symbol = StarSymbol.of(star, rating)
            Icon(Symbol(symbol.symbol), null, Modifier.size(size), tint = if (symbol == StarSymbol.EMPTY) empty else filled)
        }
    }
}

/** The stars the reader drags or taps; tapping the rating given takes it back. */
@Composable
fun InteractiveStarRating(
    rating: Double,
    onChange: (Double) -> Unit,
    total: Int = 5,
    allowsUnset: Boolean = true,
    scale: Float = 1f,
    tint: Color = Shiori.colors.label,
) {
    var pending by remember { mutableStateOf<Double?>(null) }
    val shown = pending ?: rating
    val haptics = LocalHapticFeedback.current
    val starWidth = 44.dp * scale
    val starPx = with(LocalDensity.current) { starWidth.toPx() }
    fun starsAt(x: Float): Double {
        val halves = ceil(x / (starPx / 2)).toDouble()
        return minOf(total.toDouble(), maxOf(1.0, halves / 2))
    }
    Box(Modifier.fillMaxWidth().padding(vertical = 4.dp), contentAlignment = Alignment.Center) {
        Row(
            Modifier
                .pointerInput(rating, allowsUnset) {
                    detectTapGestures { offset ->
                        val lifted = starsAt(offset.x)
                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onChange(if (lifted == rating && allowsUnset) 0.0 else lifted)
                    }
                }
                .pointerInput(rating) {
                    detectDragGestures(
                        onDrag = { change, _ ->
                            val next = starsAt(change.position.x)
                            if (next != pending) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            pending = next
                        },
                        onDragEnd = {
                            pending?.let(onChange)
                            pending = null
                        },
                        onDragCancel = { pending = null },
                    )
                },
        ) {
            for (star in 1..total) {
                val symbol = StarSymbol.of(star, shown)
                val grow by animateFloatAsState(if (star.toDouble() == ceil(shown)) 1.15f else 1f, label = "star")
                Box(Modifier.size(starWidth), contentAlignment = Alignment.Center) {
                    Icon(
                        Symbol(symbol.symbol),
                        null,
                        Modifier.size(30.dp * scale).scale(grow),
                        tint = if (symbol == StarSymbol.EMPTY) tint.copy(alpha = 0.35f) else tint,
                    )
                }
            }
        }
    }
}

/** A heart for a favourite, else the stars. */
@Composable
fun OpinionMark(rating: Double?, isFavorite: Boolean, size: Dp = 11.dp, ratingIsInherited: Boolean = false) {
    when {
        isFavorite -> Icon(Symbol("heart.fill"), L("Favori"), Modifier.size(size), tint = Shiori.colors.red)
        ratingIsInherited && rating == 5.0 ->
            Icon(Symbol("heart.fill"), L("Série favorite"), Modifier.size(size), tint = Shiori.colors.secondaryLabel)
        rating != null -> RatingStars(rating, size = size, inherited = ratingIsInherited)
    }
}
