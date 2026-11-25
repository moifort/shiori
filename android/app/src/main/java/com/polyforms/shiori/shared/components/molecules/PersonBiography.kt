package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/**
 * A person's biography: three lines, the last fading out where PLUS sits, the whole text at a tap.
 * The fade cuts the text itself rather than laying a patch of the page's colour over it, so the
 * cover's colours run on under PLUS, as on iOS.
 */
@Composable
fun PersonBiography(text: String, modifier: Modifier = Modifier) {
    var isWhole by remember { mutableStateOf(false) }
    var overflows by remember(text) { mutableStateOf(false) }
    var lastLine by remember(text) { mutableStateOf(0f) }
    var moreWidth by remember { mutableIntStateOf(0) }
    val colors = Shiori.colors
    val cut = !isWhole && overflows
    Box(modifier.fillMaxWidth().animateContentSize().plainClickable { isWhole = !isWhole }) {
        Text(
            text,
            style = Shiori.type.callout,
            color = colors.label.copy(alpha = 0.85f),
            maxLines = if (isWhole) Int.MAX_VALUE else 3,
            onTextLayout = {
                if (!isWhole) {
                    overflows = it.hasVisualOverflow
                    val last = it.lineCount - 1
                    lastLine = it.getLineBottom(last) - it.getLineTop(last)
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent {
                    drawContent()
                    if (cut) {
                        val fade = 24.dp.toPx()
                        val hole = moreWidth + 6.dp.toPx()
                        val top = size.height - lastLine
                        val start = size.width - hole
                        drawRect(
                            Brush.horizontalGradient(listOf(Color.Transparent, Color.Black), startX = start - fade, endX = start),
                            topLeft = Offset(start - fade, top),
                            size = Size(fade, lastLine),
                            blendMode = BlendMode.DstOut,
                        )
                        drawRect(Color.Black, Offset(start, top), Size(hole, lastLine), blendMode = BlendMode.DstOut)
                    }
                },
        )
        if (cut) {
            Text(
                L("PLUS"),
                style = Shiori.type.callout.copy(fontWeight = FontWeight.Bold),
                color = colors.secondaryLabel,
                modifier = Modifier.align(Alignment.BottomEnd).onSizeChanged { moreWidth = it.width },
            )
        }
    }
}

/** "Française · 1952 – 2020": a person's nationality and years. */
fun personOrigin(nationality: String?, birthYear: Int?, deathYear: Int?): String? {
    val years = when {
        birthYear != null && deathYear != null -> "$birthYear – $deathYear"
        birthYear != null -> "$birthYear"
        else -> null
    }
    val parts = listOfNotNull(nationality, years)
    return if (parts.isEmpty()) null else parts.joinToString(" · ")
}

@Preview(showBackground = true)
@Composable
private fun PersonBiographyPreview() = PreviewSurface {
    PersonBiography(
        "Auteur américain de fantasy, connu pour la Chronique du tueur de roi, dont le premier tome a paru en 2007.",
        Modifier.padding(16.dp),
    )
}
