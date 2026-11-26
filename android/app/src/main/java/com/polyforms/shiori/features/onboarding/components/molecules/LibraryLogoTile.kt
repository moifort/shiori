package com.polyforms.shiori.features.onboarding.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.onboarding.OnboardingLibrary
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/** The service's logo on a rounded tile, as the Goodreads export page draws it; once connected, a white check on its corner. */
@Composable
fun LibraryLogoTile(library: OnboardingLibrary, isDone: Boolean = false) {
    Box {
        Box(Modifier.size(64.dp).clip(RoundedCornerShape(16.dp)).background(Shiori.colors.secondaryGroupedBackground), contentAlignment = Alignment.Center) {
            Icon(painterResource(library.logo), null, Modifier.size(34.dp), tint = Color.White)
        }
        if (isDone) {
            Box(
                Modifier.align(Alignment.BottomEnd).offset(6.dp, 6.dp).size(26.dp).border(3.dp, Color.Black, CircleShape).padding(3.dp).background(Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Symbol("checkmark"), null, Modifier.size(12.dp), tint = Color.Black)
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun LibraryLogoTilePreview() = PreviewSurface(dark = true) {
    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
        LibraryLogoTile(OnboardingLibrary.AUDIBLE)
        LibraryLogoTile(OnboardingLibrary.KINDLE, isDone = true)
        LibraryLogoTile(OnboardingLibrary.GOODREADS)
    }
}
