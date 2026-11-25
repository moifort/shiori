package com.polyforms.shiori.shared.components.molecules

import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RenderEffect
import android.graphics.Shader
import android.graphics.SweepGradient
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseIn
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.AIGlow
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.rememberEffectClock
import com.polyforms.shiori.shared.components.styles.reduceMotion
import com.polyforms.shiori.shared.platform.bottomCovered
import kotlin.math.PI
import kotlin.math.sin

// iOS draws the pill in the dark appearance: its system colours, dark variants.
private val cyan = Color(0xFF64D2FF)
private val blue = Color(0xFF0A84FF)
private val purple = Color(0xFFBF5AF2)
private val pink = Color(0xFFFF375F)
private val orange = Color(0xFFFF9F0A)

private val capsule = RoundedCornerShape(50)

/** How far past the pill the body's field reaches before its blur, as iOS's `padding(-24, -20)`. */
private val fieldReachX = 24.dp
private val fieldReachY = 20.dp

/** Room around the pill for its halo to spread in: three deviations of its 14-point blur. */
private val haloRoom = 48.dp

/** Room around the words for their glow, a little more than the widest shadow (10 points). */
private val glowRoom = 24.dp

/**
 * Says that the AI is preparing the page, without covering it: a small pill floating above the
 * tab bar, filled with Siri's kind of light — two colour fields crossing as they turn — with one
 * line of white text glowing on it, its glow breathing. Never takes a touch.
 *
 * The recipe of iOS's `GeneratingPill`, layer for layer: a body made of the two turning fields,
 * reaching past the pill, blurred by 6 points, saturated by 1.5 and darkened by 0.2, then clipped
 * to the capsule; behind it a halo of the same fields added as light (`screen`), clipped to the
 * capsule, blurred by 14 points at 60 %; on top, white words under two breathing white shadows.
 * Every motion is read while drawing, so the page under it never recomposes for it.
 *
 * Below Android 12 there is no blur on a layer: the body is drawn sharp with its colour treatment,
 * the halo and the words' glow are left out.
 */
@Composable
fun GeneratingPill(modifier: Modifier = Modifier) {
    val clock = rememberEffectClock()
    val still = reduceMotion()
    val label = L("L'IA prépare la fiche")
    val density = LocalDensity.current
    val words = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold)
    // iOS's breath: `(sin(t / 2 · 2π) + 1) / 2`, a two-second swell; half-way with motion off.
    val breath = { if (still) 0.5f else ((sin(clock.value * PI) + 1) / 2).toFloat() }

    Box(
        modifier.semantics {
            contentDescription = label
            testTag = "generating"
        },
        contentAlignment = Alignment.Center,
    ) {
        if (AIGlow.canBlur) {
            // The halo: the fields added as light, clipped to the pill, blurred by 14, at 60 %.
            Box(
                Modifier
                    .matchParentSize()
                    .outset(haloRoom, haloRoom)
                    .graphicsLayer {
                        val r = AIGlow.blurRadius(14.dp, density)
                        renderEffect = BlurEffect(r, r, TileMode.Decal)
                        alpha = 0.6f
                    }
                    .lightField(clock, additive = true, clipInset = haloRoom),
            )
        }
        // The body: the fields reaching past the pill, blurred, saturated, darkened, then clipped.
        Box(Modifier.matchParentSize().clip(capsule)) {
            Box(
                Modifier
                    .matchParentSize()
                    .outset(fieldReachX, fieldReachY)
                    .graphicsLayer { renderEffect = bodyEffect(density) }
                    .lightField(clock, additive = false, colourTreated = !AIGlow.canBlur),
            )
        }
        if (AIGlow.canBlur) {
            // The words' two breathing white shadows, the wide one under the tight one.
            GlowingWords(label, words, density, breath) { b -> 6.dp + 4.dp * b to 0.35f + 0.35f * b }
            GlowingWords(label, words, density, breath) { b -> 2.5.dp + 1.5.dp * b to 0.7f + 0.3f * b }
        }
        Text(
            label,
            style = words.copy(
                shadow = Shadow(Color.Black.copy(alpha = 0.18f), Offset(0f, with(density) { 1.dp.toPx() }), AIGlow.blurRadius(0.5.dp, density)),
            ),
            color = Color.White,
            maxLines = 1,
            softWrap = false,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp),
        )
    }
}

/**
 * One white shadow of the words: a blurred white copy of them, its radius and opacity taken from
 * `breath` while drawing. Its node is grown by `glowRoom` so the blur has room to spread.
 */
@Composable
private fun BoxScope.GlowingWords(
    label: String,
    style: TextStyle,
    density: Density,
    breath: () -> Float,
    shape: (Float) -> Pair<Dp, Float>,
) {
    Box(
        Modifier
            .matchParentSize()
            .outset(glowRoom, glowRoom)
            .graphicsLayer {
                val (radius, opacity) = shape(breath())
                val r = AIGlow.blurRadius(radius, density)
                renderEffect = BlurEffect(r, r, TileMode.Decal)
                alpha = opacity
            }
            .padding(glowRoom),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = style, color = Color.White, maxLines = 1, softWrap = false, modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp))
    }
}

/** The body's treatment: blur 6, then saturation 1.5 and brightness −0.2, as iOS orders them. */
private fun bodyEffect(density: Density): androidx.compose.ui.graphics.RenderEffect? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) bodyEffectS(density) else null

@RequiresApi(Build.VERSION_CODES.S)
private fun bodyEffectS(density: Density): androidx.compose.ui.graphics.RenderEffect {
    val r = AIGlow.blurRadius(6.dp, density)
    val blur = RenderEffect.createBlurEffect(r, r, Shader.TileMode.CLAMP)
    return RenderEffect.createChainEffect(RenderEffect.createColorFilterEffect(bodyColour), blur).asComposeRenderEffect()
}

/** SwiftUI's `.saturation(1.5)` then `.brightness(-0.2)`: Rec. 709 saturation, −0.2 on each channel. */
private val bodyColour = ColorMatrixColorFilter(
    android.graphics.ColorMatrix().apply {
        setSaturation(1.5f)
        val m = array
        m[4] = -0.2f * 255
        m[9] = -0.2f * 255
        m[14] = -0.2f * 255
        set(m)
    },
)

/**
 * Two angular gradients in the AI's colours, the warm one gapped so the cool one shows through:
 * the cool one turns back once every 5.3 s, the warm one forward every 3.4 s, both about the
 * node's centre (the pill's). Laid over each other they make the body; added together as light
 * is (`screen`), the halo. `clipInset` clips them to the capsule that far inside the node.
 */
private fun Modifier.lightField(
    clock: State<Float>,
    additive: Boolean,
    clipInset: Dp = 0.dp,
    colourTreated: Boolean = false,
): Modifier = drawWithCache {
    val cx = size.width / 2
    val cy = size.height / 2
    val cool = SweepGradient(
        cx, cy,
        intArrayOf(cyan.argb, blue.argb, purple.argb, pink.argb, cyan.argb),
        floatArrayOf(0f, 0.3f, 0.55f, 0.8f, 1f),
    )
    // SwiftUI's `.clear` fades in premultiplied colour: the neighbouring hue at no opacity does the same.
    val warm = SweepGradient(
        cx, cy,
        intArrayOf(orange.argb, pink.argb, pink.copy(alpha = 0f).argb, purple.copy(alpha = 0f).argb, purple.argb, orange.argb),
        floatArrayOf(0f, 0.25f, 0.45f, 0.55f, 0.75f, 1f),
    )
    val coolPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = cool }
    val warmPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = warm
        if (additive) blendMode = android.graphics.BlendMode.SCREEN
    }
    if (colourTreated) {
        coolPaint.colorFilter = bodyColour
        warmPaint.colorFilter = bodyColour
    }
    val matrix = Matrix()
    val inset = clipInset.toPx()
    val clip = android.graphics.Path().apply {
        val h = size.height - 2 * inset
        addRoundRect(inset, inset, size.width - inset, size.height - inset, h / 2, h / 2, android.graphics.Path.Direction.CW)
    }
    onDrawBehind {
        val t = clock.value
        matrix.setRotate(-(t % 5.3f) / 5.3f * 360f, cx, cy)
        cool.setLocalMatrix(matrix)
        matrix.setRotate((t % 3.4f) / 3.4f * 360f, cx, cy)
        warm.setLocalMatrix(matrix)
        drawIntoCanvas { canvas ->
            val native = canvas.nativeCanvas
            val count = native.save()
            if (inset > 0f) native.clipPath(clip)
            if (additive) {
                // `compositingGroup()`: the halo's screen blends with the cool field only.
                native.saveLayer(0f, 0f, size.width, size.height, null)
                native.drawRect(0f, 0f, size.width, size.height, coolPaint)
                native.drawRect(0f, 0f, size.width, size.height, warmPaint)
                native.restore()
            } else {
                native.drawRect(0f, 0f, size.width, size.height, coolPaint)
                native.drawRect(0f, 0f, size.width, size.height, warmPaint)
            }
            native.restoreToCount(count)
        }
    }
}

private val Color.argb: Int get() = android.graphics.Color.argb(alpha, red, green, blue)

/** Grows a node by `x` and `y` on each side without moving its neighbours: room for a blur. */
private fun Modifier.outset(x: Dp, y: Dp): Modifier = layout { measurable, constraints ->
    val dx = x.roundToPx()
    val dy = y.roundToPx()
    val placeable = measurable.measure(
        androidx.compose.ui.unit.Constraints.fixed(constraints.maxWidth + 2 * dx, constraints.maxHeight + 2 * dy),
    )
    layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(-dx, -dy) }
}

/**
 * Where the pill is in its life, read while drawing: `open` runs 0 → 1 as it swells in (spring,
 * so it overshoots), 1 → 0 as it dissolves. Swelling in, it grows from 60 %; dissolving, it
 * shrinks to 90 %; out of focus by 6 points at either end, as iOS's stages `gone`, `open`,
 * `vanished`.
 */
private fun Modifier.pillStage(open: () -> Float, leaving: () -> Boolean, density: Density): Modifier = graphicsLayer {
    val p = open()
    val scale = if (leaving()) 0.9f + 0.1f * p else 0.6f + 0.4f * p
    scaleX = scale
    scaleY = scale
    alpha = p.coerceIn(0f, 1f)
    val blur = (1 - p).coerceIn(0f, 1f) * 6f
    renderEffect = if (AIGlow.canBlur && blur > 0.05f) {
        val r = AIGlow.blurRadius(blur.dp, density)
        BlurEffect(r, r, TileMode.Decal)
    } else {
        null
    }
}

/**
 * The pill at the foot of a page while `isGenerating`, above the tab bar and the title playing:
 * it swells in out of a blur on iOS's spring (0.5 s, bounce 0.3) and dissolves on a 0.45 s ease-in.
 */
@Composable
fun BoxScope.GeneratingPillHost(isGenerating: Boolean) {
    val still = reduceMotion()
    val density = LocalDensity.current
    val open = remember { Animatable(0f) }
    var shown by remember { mutableStateOf(false) }
    var leaving by remember { mutableStateOf(false) }
    LaunchedEffect(isGenerating) {
        if (isGenerating) {
            if (leaving) {
                leaving = false
                open.snapTo(0f)
            }
            shown = true
            // SwiftUI's `.spring(duration: 0.5, bounce: 0.3)`: stiffness (2π / 0.5)², damping 1 − 0.3.
            open.animateTo(1f, if (still) tween(300, easing = EaseOut) else spring(dampingRatio = 0.7f, stiffness = 157.9f))
        } else if (shown) {
            leaving = true
            open.animateTo(0f, tween(if (still) 300 else 450, easing = EaseIn))
            shown = false
            leaving = false
        }
    }
    if (shown) {
        GeneratingPill(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = bottomCovered() + 12.dp)
                .pillStage({ open.value }, { leaving }, density),
        )
    }
}

/** The pill at iOS's three stages, then open at 1.6×, over black as in the iOS preview. */
@Composable
fun GeneratingPillStages() {
    val density = LocalDensity.current
    Column(
        Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        GeneratingPill(Modifier.pillStage({ 0f }, { false }, density))
        GeneratingPill()
        GeneratingPill(Modifier.pillStage({ 0f }, { true }, density))
        GeneratingPill(Modifier.padding(top = 20.dp).graphicsLayer { scaleX = 1.6f; scaleY = 1.6f })
    }
}

@Preview
@Composable
private fun GeneratingPillPreview() = GeneratingPillStages()
