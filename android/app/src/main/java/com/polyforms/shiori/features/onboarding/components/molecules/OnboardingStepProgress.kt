package com.polyforms.shiori.features.onboarding.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori

/** "Étape 1 sur 3" beside one segment per library the reader ticked, the ones reached filled. */
@Composable
fun OnboardingStepProgress(number: Int, count: Int, modifier: Modifier = Modifier) {
    val label = L("Étape %lld sur %lld", number, count)
    Row(modifier.clearAndSetSemantics { contentDescription = label }, horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            for (step in 1..maxOf(count, 1)) {
                Box(Modifier.weight(1f).height(4.dp).background(if (step <= number) Color.White else Shiori.colors.tertiaryFill, CircleShape))
            }
        }
        Text(label, style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel, maxLines = 1)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun OnboardingStepProgressPreview() = PreviewSurface(dark = true) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        OnboardingStepProgress(1, 3)
        OnboardingStepProgress(2, 3)
        OnboardingStepProgress(1, 1)
    }
}
