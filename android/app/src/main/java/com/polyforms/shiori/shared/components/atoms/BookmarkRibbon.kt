package com.polyforms.shiori.shared.components.atoms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

private val Notched = GenericShape { size, _ ->
    val notch = size.width * 0.45f
    moveTo(0f, 0f)
    lineTo(size.width, 0f)
    lineTo(size.width, size.height)
    lineTo(size.width / 2, size.height - notch)
    lineTo(0f, size.height)
    close()
}

/** A white silk bookmark hanging from a cover's top edge: a paper book under way. */
@Composable
fun BookmarkRibbon(width: Dp = 14.dp) {
    Canvas(Modifier.size(width, width * 2.15f).shadow(2.dp, Notched, clip = false)) {
        val notch = size.width * 0.45f
        val path = Path().apply {
            moveTo(0f, 0f)
            lineTo(size.width, 0f)
            lineTo(size.width, size.height)
            lineTo(size.width / 2, size.height - notch)
            lineTo(0f, size.height)
            close()
        }
        drawPath(
            path,
            Brush.horizontalGradient(
                listOf(Color(0xFFD9D9D9), Color.White, Color(0xFFCFCFCF)),
                startX = 0f,
                endX = size.width,
            ),
        )
        drawLine(Color.Transparent, Offset.Zero, Offset.Zero)
    }
}
