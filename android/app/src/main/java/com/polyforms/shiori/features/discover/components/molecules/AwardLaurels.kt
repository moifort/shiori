package com.polyforms.shiori.features.discover.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.AwardMention
import com.polyforms.shiori.features.discover.LiteraryAward
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * A prize between its laurels, taller than its lines so they frame it: its name, its year, what it
 * crowns. On an image, so always in white. `compact` is the small emblem a card's side wears.
 */
@Composable
fun AwardLaurels(mention: AwardMention, compact: Boolean = false) {
    Row(horizontalArrangement = Arrangement.spacedBy(if (compact) 3.dp else 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol("laurel.leading"), null, Modifier.size(if (compact) 24.dp else 44.dp), tint = Color.White)
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (compact) 0.dp else 1.dp)) {
            Text(mention.award.shortName.uppercase(), style = TextStyle(fontSize = if (compact) 9.sp else 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp), color = Color.White, maxLines = 1)
            Text(mention.year.toString(), style = TextStyle(fontSize = if (compact) 16.sp else 23.sp, fontWeight = FontWeight.ExtraBold), color = Color.White, maxLines = 1)
            Text(mention.award.categoryName, style = TextStyle(fontSize = if (compact) 10.sp else 12.sp), color = Color.White.copy(alpha = 0.85f), maxLines = 1)
        }
        Icon(Symbol("laurel.trailing"), null, Modifier.size(if (compact) 24.dp else 44.dp), tint = Color.White)
    }
}

/** What the prize crowns, under its year. */
val LiteraryAward.categoryName: String
    get() = when (this) {
        LiteraryAward.LOCUS_SCIENCE_FICTION -> L("Meilleur roman de SF")
        LiteraryAward.LOCUS_FANTASY -> L("Meilleur roman de fantasy")
        else -> L("Meilleur roman")
    }

@Preview(showBackground = true)
@Composable
private fun AwardLaurelsPreview() = PreviewSurface(dark = true) {
    Column(Modifier.background(Color.Black).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        AwardLaurels(AwardMention(LiteraryAward.HUGO, 2026))
        AwardLaurels(AwardMention(LiteraryAward.LOCUS_FANTASY, 2025), compact = true)
    }
}
