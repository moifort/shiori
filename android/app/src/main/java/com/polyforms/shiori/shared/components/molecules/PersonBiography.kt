package com.polyforms.shiori.shared.components.molecules

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
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

/** A person's biography: three lines ending on PLUS, the whole text at a tap. */
@Composable
fun PersonBiography(text: String, modifier: Modifier = Modifier, ground: Color = Shiori.colors.groupedBackground) {
    var isWhole by remember { mutableStateOf(false) }
    var overflows by remember(text) { mutableStateOf(false) }
    val colors = Shiori.colors
    Box(modifier.fillMaxWidth().animateContentSize().plainClickable { isWhole = !isWhole }) {
        Text(
            text,
            style = Shiori.type.callout,
            color = colors.label.copy(alpha = 0.85f),
            maxLines = if (isWhole) Int.MAX_VALUE else 3,
            onTextLayout = { if (!isWhole) overflows = it.hasVisualOverflow },
            modifier = Modifier.fillMaxWidth(),
        )
        if (!isWhole && overflows) {
            Row(Modifier.align(Alignment.BottomEnd).height(IntrinsicSize.Min)) {
                Box(Modifier.width(24.dp).fillMaxHeight().background(Brush.horizontalGradient(listOf(Color.Transparent, ground))))
                Text(
                    L("PLUS"),
                    style = Shiori.type.callout.copy(fontWeight = FontWeight.Bold),
                    color = colors.secondaryLabel,
                    modifier = Modifier.background(ground).padding(start = 6.dp),
                )
            }
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
