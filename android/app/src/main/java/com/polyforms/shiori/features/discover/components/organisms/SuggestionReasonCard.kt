package com.polyforms.shiori.features.discover.components.organisms

import com.polyforms.shiori.shared.components.styles.ShioriTheme
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.SuggestionReference
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/** Why this book, over the blurred cover of the first book it leans on, each one a way back. */
@Composable
fun SuggestionReasonCard(reason: String, references: List<SuggestionReference>, onOpen: (SuggestionReference) -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    ShioriTheme(dark = true) {
        // Drawn dark in either appearance, as iOS forces `.colorScheme(.dark)` on it.
        Box(Modifier.fillMaxWidth().clip(shape)) {
            CoverBackdrop(references.firstNotNullOfOrNull { it.coverURL }, Modifier.matchParentSize(), ground = Color.Transparent)
            Box(Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.4f)))
            Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(L("Pourquoi ce livre").uppercase(), style = Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold), color = Color.White.copy(alpha = 0.75f))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    val covers = references.filter { it.coverURL != null }.take(2)
                    if (covers.isNotEmpty()) {
                        Box(Modifier.padding(start = 10.dp).width(if (covers.size > 1) 82.dp else 72.dp).height(if (covers.size > 1) 120.dp else 108.dp)) {
                            covers.withIndex().reversed().forEach { (index, reference) ->
                                Box(Modifier.offset(if (index == 0) 0.dp else 10.dp, if (index == 0 && covers.size > 1) 12.dp else 0.dp).rotate(if (index == 0) 0f else 6f)) {
                                    BookCover(reference.cover, 72.dp, showsFormatBadge = false)
                                }
                            }
                        }
                    }
                    Text(reason, style = Shiori.type.body, color = Color.White.copy(alpha = 0.95f), modifier = Modifier.weight(1f))
                }
                if (references.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        references.forEach { reference ->
                            Row(
                                Modifier.fillMaxWidth().height(44.dp).clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.15f))
                                    .border(0.5.dp, Color.White.copy(alpha = 0.28f), CircleShape)
                                    .plainClickable { onOpen(reference) }
                                    .padding(start = 18.dp, end = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Text(reference.title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                                val rating = reference.rating
                                if (reference.favorite) {
                                    Icon(Symbol("heart.fill"), L("Favori"), Modifier.size(15.dp), tint = Color.White)
                                } else if (rating != null) {
                                    RatingStars(rating, size = 10.dp, monochrome = true, tint = Color.White)
                                }
                                Icon(Symbol("chevron.right"), null, Modifier.size(10.dp), tint = Color.White.copy(alpha = 0.55f))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SuggestionReasonCardPreview() = PreviewSurface(dark = true) {
    val suggestion = DebugFixtures.discoveries.suggestions[0]
    Box(Modifier.background(Color.Black).padding(20.dp)) { SuggestionReasonCard(suggestion.reason, suggestion.references) {} }
}
