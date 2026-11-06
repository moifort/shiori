package com.polyforms.shiori.shared.shell

import android.annotation.SuppressLint
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.glass
import kotlin.math.ceil
import kotlin.math.sqrt

/** The launch covers bundled with the app, shuffled once per launch. */
@SuppressLint("DiscouragedApi")
@Composable
fun rememberLaunchCovers(): List<Int> {
    val context = LocalContext.current
    return remember {
        (1..99).mapNotNull { n ->
            context.resources.getIdentifier("launch_cover_%02d".format(n), "drawable", context.packageName).takeIf { it != 0 }
        }.shuffled()
    }
}

/**
 * Covers drifting in rows across a band tilted by twelve degrees, every other row the other
 * way: the wall behind the sign-in and the launch.
 */
@Composable
fun CoverDrift(covers: List<Int>, moving: Boolean = true, modifier: Modifier = Modifier) {
    if (covers.isEmpty()) return
    BoxWithConstraints(modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val w = maxWidth.value
        val h = maxHeight.value
        val diagonal = sqrt(w * w + h * h)
        val coverW = 96f
        val coverH = 146f
        val spacing = 14f
        val pitch = coverH + spacing
        val step = coverW + spacing
        val rowCount = ceil(diagonal / pitch).toInt() + 1
        val across = ceil(diagonal / step).toInt() + 1
        val hands = (0 until minOf(rowCount, covers.size)).map { hand -> covers.indices.filter { it % minOf(rowCount, covers.size) == hand }.map { covers[it] } }
        val transition = rememberInfiniteTransition(label = "drift")
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
                    val pace = 26f * (0.8f + 0.4f * ((row * 7) % 5) / 4f)
                    val progress by transition.animateFloat(
                        0f,
                        if (moving) 1f else 0f,
                        infiniteRepeatable(tween((repeatWidth / pace * 1000).toInt(), easing = LinearEasing)),
                        label = "row$row",
                    )
                    val leftward = row % 2 == 0
                    val shift = if (leftward) -progress * repeatWidth else -repeatWidth + progress * repeatWidth
                    Row(
                        Modifier.graphicsLayer { translationX = with(density) { shift.dp.toPx() } },
                        horizontalArrangement = Arrangement.spacedBy(spacing.dp),
                    ) {
                        repeat(perStrip + across) { index ->
                            Image(
                                painterResource(hand[index % hand.size]),
                                null,
                                Modifier.size(coverW.dp, coverH.dp).clip(RoundedCornerShape(5.dp)),
                                contentScale = ContentScale.Crop,
                            )
                        }
                    }
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
