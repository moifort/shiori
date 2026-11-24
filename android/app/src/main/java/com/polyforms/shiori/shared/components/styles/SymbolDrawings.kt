package com.polyforms.shiori.shared.components.styles

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.graphics.vector.group
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

/**
 * The SF Symbols Material has no fair stand-in for, drawn after iOS on a 24 grid: the laurels
 * framing a prize, the binoculars of an awaited edition, the struck bookmark, the full tray,
 * the open book and the counter-clockwise arrow.
 */
internal object SymbolDrawings {
    private val ink = SolidColor(Color.Black)

    private fun icon(name: String, build: ImageVector.Builder.() -> Unit) =
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply(build).build()

    private fun ImageVector.Builder.stroke(d: String, width: Float = 1.7f) = addPath(
        addPathNodes(d), stroke = ink, strokeLineWidth = width,
        strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
    )

    private fun ImageVector.Builder.fill(d: String) = addPath(addPathNodes(d), fill = ink)

    /** Material's refresh arrow turned the other way, as `arrow.counterclockwise` turns. */
    val arrowCounterclockwise: ImageVector by lazy {
        icon("arrow.counterclockwise") {
            group(scaleX = -1f, pivotX = 12f) {
                fill(
                    "M17.65,6.35C16.2,4.9 14.21,4 12,4c-4.42,0 -7.99,3.58 -7.99,8s3.57,8 7.99,8" +
                        "c3.73,0 6.84,-2.55 7.73,-6h-2.08c-0.82,2.33 -3.04,4 -5.65,4 -3.31,0 -6,-2.69 -6,-6" +
                        "s2.69,-6 6,-6c1.66,0 3.14,0.69 4.22,1.78L13,11h7V4l-2.35,2.35z",
                )
            }
        }
    }

    /** Two barrels joined by a bridge, their lenses at the bottom. */
    private fun binocularsPaths(filled: Boolean): ImageVector.Builder.() -> Unit = {
        val barrels = "M4.5,6.5 L8.5,6.5 L10,11 L10,17 A3.5,3.5 0 0 1 3,17 L3,11 Z " +
            "M15.5,6.5 L19.5,6.5 L21,11 L21,17 A3.5,3.5 0 0 1 14,17 L14,11 Z"
        if (filled) fill(barrels) else stroke(barrels)
        stroke("M10,11.5 L14,11.5 M10,14.5 L14,14.5")
        stroke("M5,6.5 L5,4.5 L8,4.5 L8,6.5 M16,6.5 L16,4.5 L19,4.5 L19,6.5")
    }

    val binoculars: ImageVector by lazy { icon("binoculars", binocularsPaths(filled = false)) }
    val binocularsFill: ImageVector by lazy { icon("binoculars.fill", binocularsPaths(filled = true)) }

    /** The bookmark crossed out, as `bookmark.slash`. */
    val bookmarkSlash: ImageVector by lazy {
        icon("bookmark.slash") {
            stroke("M6,5.5 L6,20.5 L12,16.5 L18,20.5 L18,5.5 A1.5,1.5 0 0 0 16.5,4 L7.5,4 A1.5,1.5 0 0 0 6,5.5 Z")
            stroke("M3.5,3.5 L20.5,20.5")
        }
    }

    /** A tray holding two sheets, as `tray.full`. */
    val trayFull: ImageVector by lazy {
        icon("tray.full") {
            stroke("M3,13 L5.5,5 L18.5,5 L21,13 L21,18 A2,2 0 0 1 19,20 L5,20 A2,2 0 0 1 3,18 Z")
            stroke("M3,13 L8,13 A4,4 0 0 0 16,13 L21,13")
            stroke("M8,8 L16,8 M7.2,10.5 L16.8,10.5")
        }
    }

    /** Two pages open on their spine, as SF's `book`. */
    val book: ImageVector by lazy {
        icon("book") {
            stroke(
                "M12,6.5 C10,5 7,4.5 3,5 L3,18.5 C7,18 10,18.5 12,20 C14,18.5 17,18 21,18.5 " +
                    "L21,5 C17,4.5 14,5 12,6.5 Z M12,6.5 L12,20",
            )
        }
    }

    /**
     * A laurel branch curving up the left of a prize, leaves on both sides of its stem; the
     * trailing one is its mirror. Positions along an arc of the circle centred at (17, 12).
     */
    private fun laurel(name: String, mirrored: Boolean) = icon(name) {
        group(scaleX = if (mirrored) -1f else 1f, pivotX = 12f) {
            val cx = 17f
            val cy = 12f
            val r = 10f
            fun at(deg: Float, offset: Float): Pair<Float, Float> {
                val a = Math.toRadians(deg.toDouble())
                return (cx + (r + offset) * cos(a)).toFloat() to (cy + (r + offset) * sin(a)).toFloat()
            }
            val (sx, sy) = at(115f, 0f)
            val (ex, ey) = at(248f, 0f)
            stroke("M$sx,$sy A$r,$r 0 0 1 $ex,$ey", width = 1.2f)
            // The leaf at the origin, its tip up; turned along the stem and set beside it.
            fun leaf(deg: Float, offset: Float, tilt: Float, size: Float) {
                val (x, y) = at(deg, offset)
                group(rotate = deg + 180f + tilt, translationX = x, translationY = y) {
                    fill("M0,${-size} Q${size * 0.55f},0 0,$size Q${-size * 0.55f},0 0,${-size} Z")
                }
            }
            listOf(128f, 148f, 168f, 188f, 208f, 228f).forEach { leaf(it, 1.8f, -32f, 2.7f) }
            listOf(138f, 160f, 182f, 204f, 226f).forEach { leaf(it, -1.5f, 30f, 2.1f) }
            leaf(252f, 0.6f, 0f, 2.6f)
        }
    }

    val laurelLeading: ImageVector by lazy { laurel("laurel.leading", mirrored = false) }
    val laurelTrailing: ImageVector by lazy { laurel("laurel.trailing", mirrored = true) }
}
