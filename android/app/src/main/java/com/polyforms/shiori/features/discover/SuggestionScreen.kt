package com.polyforms.shiori.features.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.R
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryButtons
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactLink
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator

/**
 * A discovery's page: the book described on the spot, why it was chosen with the books it leans
 * on, and the same buttons as its tile — what the page decides takes it off the line.
 */
@Composable
fun SuggestionScreen(suggestion: Suggestion, choices: DiscoveryChoices, onChoice: suspend (Suggestion, DiscoveryChoice) -> Boolean) {
    val describer = remember(suggestion.id) { ReleaseDescriber() }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { describer.describe(suggestion.seed) }
    val shown = suggestion.cover.described(describer.description)
    val state = when {
        suggestion.state == AwaitedState.ANNOUNCED && suggestion.date?.let { ReleaseDateText.isUpcoming(it) } == true -> BookState.release(suggestion.date)
        !suggestion.watched -> null
        else -> BookState(suggestion.stateLine, suggestion.stateTint)
    }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).verticalScroll(rememberScrollState())) {
            BookHero(shown, state = state, isAwaited = suggestion.awaitedEditionId != null, showsLength = false) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    DiscoveryButtons(suggestion, choices, onChoice, addsInFull = true)
                }
            }
            Column(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                SuggestionReasonCard(suggestion.reason, suggestion.references) { reference ->
                    val seriesId = reference.seriesId
                    navigator.push { if (reference.citesSaga && seriesId != null) SeriesScreen(seriesId) else BookScreen(reference.bookId) }
                }
                if (!describer.isDescribing) shown.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Informations"))
                    val original = if (suggestion.title == suggestion.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), suggestion.originalTitle, isWide = true))
                    val links = suggestion.storeURL?.let { url ->
                        if (suggestion.format == ReleaseFormat.AUDIOBOOK) FactLink("audible", L("Écouter sur Audible"), R.drawable.audible_logo, url) else FactLink("amazon", L("Voir sur Amazon"), R.drawable.amazon_logo, url)
                    }
                    FactGrid(listOf(FactGroup(original + shown.readOnlyFactTiles)), listOfNotNull(links))
                }
            }
        }
        ScreenBar()
        GeneratingPillHost(describer.isDescribing)
    }
}

/** Why this book, over the blurred cover of the first book it leans on, each one a way back. */
@Composable
fun SuggestionReasonCard(reason: String, references: List<SuggestionReference>, onOpen: (SuggestionReference) -> Unit) {
    val shape = RoundedCornerShape(18.dp)
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
                                Icon(Symbol("heart.fill"), L("Favori"), Modifier.size(15.dp), tint = Shiori.colors.red)
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
