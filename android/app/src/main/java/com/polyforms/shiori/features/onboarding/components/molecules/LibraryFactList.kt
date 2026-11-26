package com.polyforms.shiori.features.onboarding.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.onboarding.OnboardingLibrary
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * A rounded box of lines, each a symbol in a small circle, a title and a detail: the same box as
 * the Goodreads export steps, a symbol in place of the number.
 */
@Composable
fun LibraryFactList(facts: List<OnboardingLibrary.Fact>, modifier: Modifier = Modifier) {
    val colors = Shiori.colors
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(colors.secondaryGroupedBackground).padding(horizontal = 16.dp)) {
        facts.forEachIndexed { index, fact ->
            if (index > 0) ShioriDivider(Modifier.padding(start = 40.dp))
            Row(Modifier.padding(vertical = 10.dp).semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(28.dp).clip(CircleShape).background(colors.tertiaryFill), contentAlignment = Alignment.Center) {
                    Icon(Symbol(fact.symbol), null, Modifier.size(15.dp), tint = colors.label)
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(fact.title, style = Shiori.type.body, color = colors.label)
                    Text(fact.detail, style = Shiori.type.footnote, color = colors.secondaryLabel)
                }
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun LibraryFactListPreview() = PreviewSurface(dark = true) {
    LibraryFactList(OnboardingLibrary.AUDIBLE.brings, Modifier.padding(16.dp))
}
